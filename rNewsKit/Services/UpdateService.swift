import Foundation
import Muon
import Sinope
import CBGPromise
import Result

protocol NetworkClientDelegate: class {
    func didDownloadImage(image: Image, url: NSURL)
    func didDownloadFeed(feed: ImportableFeed, url: NSURL)
    func didDownloadData(data: NSData, url: NSURL)
    func didFailToDownloadDataFromUrl(url: NSURL, error: NSError?)
}

final class URLSessionDelegate: NSObject, NSURLSessionDownloadDelegate {
    weak var delegate: NetworkClientDelegate?

    func URLSession(_ : NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL url: NSURL) {
        guard let data = NSData(contentsOfURL: url) else {
            let error = NSError(domain: "com.rachelbrindle.rNews", code: 20, userInfo: nil)
            self.delegate?.didFailToDownloadDataFromUrl(url, error: error)
            return
        }
        let originalUrl = downloadTask.originalRequest?.URL ?? NSURL()
        let mimetype = downloadTask.response?.MIMEType

        if mimetype?.hasPrefix("image") == true, let image = Image(data: data) {
            self.delegate?.didDownloadImage(image, url: originalUrl)
            return
        } else if let str = String(data: data, encoding: NSUTF8StringEncoding) {
            let feedParser = Muon.FeedParser(string: str)
            feedParser.failure { _ in
                self.delegate?.didDownloadData(data, url: originalUrl)
            }
            feedParser.success { feed in
                self.delegate?.didDownloadFeed(feed, url: originalUrl)
            }
            feedParser.start()
            return
        }
        self.delegate?.didDownloadData(data, url: originalUrl)
    }

    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        let url = task.originalRequest?.URL ?? NSURL()
        self.delegate?.didFailToDownloadDataFromUrl(url, error: error)
    }
}

protocol UpdateServiceType: class {
    func updateFeed(feed: rNewsKit.Feed, callback: (rNewsKit.Feed, NSError?) -> Void)
    func updateFeeds(date: NSDate?) -> Future<Result<(NSDate, [rNewsKit.Feed]), RNewsError>>
}

final class UpdateService: UpdateServiceType, NetworkClientDelegate {
    private let dataServiceFactory: DataServiceFactoryType
    private let urlSession: NSURLSession
    private let workerQueue: NSOperationQueue
    private let sinopeRepository: Sinope.Repository

    private var callbacksInProgress: [NSURL: (feed: rNewsKit.Feed, callback: ((rNewsKit.Feed, NSError?) -> Void))] = [:]

    init(dataServiceFactory: DataServiceFactoryType,
         urlSession: NSURLSession,
         urlSessionDelegate: URLSessionDelegate,
         workerQueue: NSOperationQueue,
         sinopeRepository: Sinope.Repository) {
        self.dataServiceFactory = dataServiceFactory
        self.urlSession = urlSession
        self.workerQueue = workerQueue
        self.sinopeRepository = sinopeRepository
        urlSessionDelegate.delegate = self
    }

    func updateFeed(feed: Feed, callback: (Feed, NSError?) -> Void) {
        guard let url = feed.url else {
            callback(feed, nil)
            return
        }
        self.callbacksInProgress[url] = (feed, callback)
        self.downloadURL(url)
    }

    func updateFeeds(date: NSDate?) -> Future<Result<(NSDate, [rNewsKit.Feed]), RNewsError>> {
        return self.sinopeRepository.fetch(date).map {result -> Result<(NSDate, [rNewsKit.Feed]), RNewsError> in
            switch result {
            case let .Success(date, sinopeFeeds):
                return .Success(date, self.updateFeedsFromSinopeFeeds(sinopeFeeds))
            case let .Failure(error):
                return .Failure(RNewsError.Backend(error))
            }
        }
    }

    private func updateFeedsFromSinopeFeeds(sinopeFeeds: [Sinope.Feed]) -> [rNewsKit.Feed] {
        let dataService = self.dataServiceFactory.currentDataService
        guard let feeds = dataService.allFeeds().wait()?.value else { return [] }
        var updatedFeeds: [rNewsKit.Feed] = []
        for importableFeed in sinopeFeeds {
            let predicate = NSPredicate(format: "url == %@", importableFeed.link)
            guard let feed = feeds.filterWithPredicate(predicate).first else {
                continue
            }

            self.dataServiceFactory.currentDataService.updateFeed(feed, info: importableFeed).map { res -> Void in
                switch res {
                case .Success():
//                    if feed.image == nil, let imageUrl = singleFeed.imageURL where !imageUrl.absoluteString.isEmpty {
//                        self.callbacksInProgress[imageUrl] = feedCallback
//                        self.downloadURL(imageUrl)
//                    }
                    updatedFeeds.append(feed)
                    break
                case .Failure(_):
                    break
                }
            }.wait()
        }
        return updatedFeeds
    }

    // MARK: NetworkClientDelegate

    func didDownloadFeed(singleFeed: ImportableFeed, url: NSURL) {
        guard let feedCallback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValueForKey(url)
        let feed = feedCallback.feed
        let callback = feedCallback.callback
        self.workerQueue.addOperationWithBlock {
            self.dataServiceFactory.currentDataService.updateFeed(feed, info: singleFeed).then { _ in
                if feed.image == nil, let imageUrl = singleFeed.imageURL where !imageUrl.absoluteString.isEmpty {
                    self.callbacksInProgress[imageUrl] = feedCallback
                    self.downloadURL(imageUrl)
                } else {
                    callback(feed, nil)
                }
            }
        }
    }

    func didDownloadImage(image: Image, url: NSURL) {
        guard let imageCallback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValueForKey(url)
        let feed = imageCallback.feed
        let callback = imageCallback.callback
        feed.image = image
        self.workerQueue.addOperationWithBlock {
            self.dataServiceFactory.currentDataService.saveFeed(feed).then { _ in
                callback(feed, nil)
            }
        }
    }

    func didDownloadData(data: NSData, url: NSURL) {
        let error = NSError(domain: "com.rachelbrindle.rnews.parseError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to parse data"])
        self.didFailToDownloadDataFromUrl(url, error: error)
    }

    func didFailToDownloadDataFromUrl(url: NSURL, error: NSError?) {
        guard error != nil, let callback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValueForKey(url)
        let feed = callback.feed
        let function = callback.callback
        self.workerQueue.addOperationWithBlock {
            function(feed, error)
        }
    }

    // MARK: Private

    private func downloadURL(url: NSURL) {
        let request = NSURLRequest(URL: url, cachePolicy: .UseProtocolCachePolicy, timeoutInterval: 30)
        self.urlSession.downloadTaskWithRequest(request).resume()
    }
}

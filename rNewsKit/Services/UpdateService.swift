import Foundation
import Muon
import Sinope
import CBGPromise
import Result

protocol NetworkClientDelegate: class {
    func didDownloadImage(_ image: Image, url: URL)
    func didDownloadFeed(_ feed: ImportableFeed, url: URL)
    func didDownloadData(_ data: Data, url: URL)
    func didFailToDownloadDataFromUrl(_ url: URL, error: NSError?)
}

final class URLSessionDelegate: NSObject, URLSessionDownloadDelegate {
    weak var delegate: NetworkClientDelegate?

    func urlSession(_ : URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            let error = NSError(domain: "com.rachelbrindle.rNews", code: 20, userInfo: nil)
            self.delegate?.didFailToDownloadDataFromUrl(url, error: error)
            return
        }
        let originalUrl = downloadTask.originalRequest?.url ?? URL()
        let mimetype = downloadTask.response?.mimeType

        if mimetype?.hasPrefix("image") == true, let image = Image(data: data) {
            self.delegate?.didDownloadImage(image, url: originalUrl)
            return
        } else if let str = String(data: data, encoding: String.Encoding.utf8) {
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

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let url = task.originalRequest?.url ?? URL()
        self.delegate?.didFailToDownloadDataFromUrl(url, error: error)
    }
}

protocol UpdateServiceType: class {
    func updateFeed(_ feed: rNewsKit.Feed, callback: (rNewsKit.Feed, NSError?) -> Void)
    func updateFeeds(_ progress: (Int, Int) -> Void) ->
        Future<Result<[rNewsKit.Feed], RNewsError>>
}

final class UpdateService: UpdateServiceType, NetworkClientDelegate {
    private let dataServiceFactory: DataServiceFactoryType
    private let urlSession: URLSession
    private let workerQueue: OperationQueue
    private let sinopeRepository: Sinope.Repository

    private var callbacksInProgress: [URL: (feed: rNewsKit.Feed, callback: ((rNewsKit.Feed, NSError?) -> Void))] = [:]

    init(dataServiceFactory: DataServiceFactoryType,
         urlSession: URLSession,
         urlSessionDelegate: URLSessionDelegate,
         workerQueue: OperationQueue,
         sinopeRepository: Sinope.Repository) {
        self.dataServiceFactory = dataServiceFactory
        self.urlSession = urlSession
        self.workerQueue = workerQueue
        self.sinopeRepository = sinopeRepository
        urlSessionDelegate.delegate = self
    }

    func updateFeed(_ feed: Feed, callback: (Feed, NSError?) -> Void) {
        self.callbacksInProgress[feed.url as URL] = (feed, callback)
        self.downloadURL(feed.url as URL)
    }

    func updateFeeds(_ progress: (Int, Int) -> Void) ->
        Future<Result<[rNewsKit.Feed], RNewsError>> {
            let dataService = self.dataServiceFactory.currentDataService
            guard let feedsArray = dataService.allFeeds().wait()?.value else {
                let promise = Promise<Result<[rNewsKit.Feed], RNewsError>>()
                promise.resolve(.Failure(RNewsError.Unknown))
                return promise.future
            }
            let feeds = Array(feedsArray)

            var urlsToDates: [URL: Date] = [:]
            for feed in feeds {
                if feed.lastUpdated != NSDate(timeIntervalSinceReferenceDate: 0) {
                    urlsToDates[feed.url] = feed.lastUpdated
                }
            }
            return self.sinopeRepository.fetch(urlsToDates).map {result -> Result<[rNewsKit.Feed], RNewsError> in
                switch result {
                case let .Success(sinopeFeeds):
                    progress(sinopeFeeds.count, 2 * sinopeFeeds.count)
                    return .Success(self.updateFeedsFromSinopeFeeds(sinopeFeeds, progressCallback: progress))
                case let .Failure(error):
                    return .Failure(RNewsError.Backend(error))
                }
            }
    }

    private func updateFeedsFromSinopeFeeds(_ sinopeFeeds: [Sinope.Feed], progressCallback: (Int, Int) -> Void) ->
        [rNewsKit.Feed] {
            var current = sinopeFeeds.count
            let total = current * 2
            let dataService = self.dataServiceFactory.currentDataService
            guard let feedsArray = dataService.allFeeds().wait()?.value else { return [] }
            let feeds = Array(feedsArray)
            var updatedFeeds: [rNewsKit.Feed] = []
            for importableFeed in sinopeFeeds {
                current += 1
                progressCallback(current, total)
                let dataService = self.dataServiceFactory.currentDataService
                let feed: rNewsKit.Feed
                if let existingFeed = feeds.objectPassingTest({ $0.url == importableFeed.link || $0.title == importableFeed.title }) {
                    feed = existingFeed
                } else {
                    let promise = dataService.createFeed { $0.url = importableFeed.url }

                    if let createdFeed = promise.wait()?.value {
                        feed = createdFeed
                    } else { return [] }
                }

                self.dataServiceFactory.currentDataService.updateFeed(feed, info: importableFeed).map { res -> Void in
                    switch res {
                    case .Success():
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

    func didDownloadFeed(_ singleFeed: ImportableFeed, url: URL) {
        guard let feedCallback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValue(forKey: url)
        let feed = feedCallback.feed
        let callback = feedCallback.callback
        self.workerQueue.addOperationWithBlock {
            self.dataServiceFactory.currentDataService.updateFeed(feed, info: singleFeed).then { _ in
                if feed.image == nil, let imageUrl = singleFeed.imageURL , !imageUrl.absoluteString.isEmpty {
                    self.callbacksInProgress[imageUrl] = feedCallback
                    self.downloadURL(imageUrl)
                } else {
                    callback(feed, nil)
                }
            }
        }
    }

    func didDownloadImage(_ image: Image, url: URL) {
        guard let imageCallback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValue(forKey: url)
        let feed = imageCallback.feed
        let callback = imageCallback.callback
        feed.image = image
        self.workerQueue.addOperationWithBlock {
            self.dataServiceFactory.currentDataService.saveFeed(feed).then { _ in
                callback(feed, nil)
            }
        }
    }

    func didDownloadData(_ data: Data, url: URL) {
        let error = NSError(domain: "com.rachelbrindle.rnews.parseError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to parse data"])
        self.didFailToDownloadDataFromUrl(url, error: error)
    }

    func didFailToDownloadDataFromUrl(_ url: URL, error: NSError?) {
        guard error != nil, let callback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValue(forKey: url)
        let feed = callback.feed
        let function = callback.callback
        self.workerQueue.addOperation {
            function(feed, error)
        }
    }

    // MARK: Private

    private func downloadURL(_ url: URL) {
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        self.urlSession.downloadTask(with: request).resume()
    }
}

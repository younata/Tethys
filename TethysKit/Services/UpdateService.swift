import Foundation
import Muon
import Sinope
import CBGPromise
import Result

protocol NetworkClientDelegate: class {
    func didDownloadImage(_ image: Image, url: URL)
    func didDownloadFeed(_ feed: ImportableFeed, url: URL)
    func didDownloadData(_ data: Data, url: URL)
    func didFailToDownloadDataFromUrl(_ url: URL, error: Error?)
}

final class TethysKitURLSessionDelegate: NSObject, URLSessionDownloadDelegate {
    weak var delegate: NetworkClientDelegate?

    func urlSession(_ : URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo url: URL) {
        guard let data = try? Data(contentsOf: url), let originalUrl = downloadTask.originalRequest?.url else {
            let error = NSError(domain: "com.rachelbrindle.Tethys", code: 20, userInfo: nil)
            self.delegate?.didFailToDownloadDataFromUrl(url, error: error)
            return
        }
        let mimetype = downloadTask.response?.mimeType

        if mimetype?.hasPrefix("image") == true, let image = Image(data: data) {
            self.delegate?.didDownloadImage(image, url: originalUrl)
            return
        } else if let str = String(data: data, encoding: String.Encoding.utf8) {
            let feedParser = Muon.FeedParser(string: str)
            _ = feedParser.failure { _ in
                self.delegate?.didDownloadData(data, url: originalUrl)
            }
            _ = feedParser.success { feed in
                self.delegate?.didDownloadFeed(feed, url: originalUrl)
            }
            feedParser.start()
            return
        }
        self.delegate?.didDownloadData(data, url: originalUrl)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let url = task.originalRequest?.url {
            self.delegate?.didFailToDownloadDataFromUrl(url, error: error)
        }
    }
}

protocol UpdateServiceType: class {
    func updateFeed(_ feed: TethysKit.Feed) -> Future<Result<TethysKit.Feed, TethysError>>
    func updateFeeds(_ progress: @escaping (Int, Int) -> Void) ->
        Future<Result<[TethysKit.Feed], TethysError>>
}

final class UpdateService: UpdateServiceType, NetworkClientDelegate {
    private let dataServiceFactory: DataServiceFactoryType
    private let urlSession: URLSession
    private let workerQueue: OperationQueue
    private let sinopeRepository: Sinope.Repository

    private var callbacksInProgress: [URL: (feed: TethysKit.Feed,
                                            promise: Promise<Result<TethysKit.Feed, TethysError>>)] = [:]

    init(dataServiceFactory: DataServiceFactoryType,
         urlSession: URLSession,
         urlSessionDelegate: TethysKitURLSessionDelegate,
         workerQueue: OperationQueue,
         sinopeRepository: Sinope.Repository) {
        self.dataServiceFactory = dataServiceFactory
        self.urlSession = urlSession
        self.workerQueue = workerQueue
        self.sinopeRepository = sinopeRepository
        urlSessionDelegate.delegate = self
    }

    func updateFeed(_ feed: Feed) -> Future<Result<TethysKit.Feed, TethysError>> {
        let promise = Promise<Result<TethysKit.Feed, TethysError>>()
        self.callbacksInProgress[feed.url] = (feed, promise)
        self.downloadURL(feed.url)
        return promise.future
    }

    func updateFeeds(_ progress: @escaping (Int, Int) -> Void) ->
        Future<Result<[TethysKit.Feed], TethysError>> {
            let dataService = self.dataServiceFactory.currentDataService
            guard let feedsArray = dataService.allFeeds().wait()?.value else {
                let promise = Promise<Result<[TethysKit.Feed], TethysError>>()
                promise.resolve(.failure(TethysError.unknown))
                return promise.future
            }
            let feeds = Array(feedsArray)

            var urlsToDates: [URL: Date] = [:]
            for feed in feeds {
                if feed.lastUpdated != Date(timeIntervalSinceReferenceDate: 0) {
                    urlsToDates[feed.url] = feed.lastUpdated
                }
            }
            return self.sinopeRepository.fetch(urlsToDates).map {result -> Result<[TethysKit.Feed], TethysError> in
                switch result {
                case let .success(sinopeFeeds):
                    progress(sinopeFeeds.count, 2 * sinopeFeeds.count)
                    return .success(self.updateFeedsFromSinopeFeeds(sinopeFeeds, progressCallback: progress))
                case let .failure(error):
                    return .failure(TethysError.backend(error))
                }
            }
    }

    private func updateFeedsFromSinopeFeeds(_ sinopeFeeds: [Sinope.Feed],
                                            progressCallback: @escaping (Int, Int) -> Void) -> [TethysKit.Feed] {
        var current = sinopeFeeds.count
        let total = current * 2
        var updatedFeeds: [TethysKit.Feed] = []
        for importableFeed in sinopeFeeds {
            current += 1
            progressCallback(current, total)
            let dataService = self.dataServiceFactory.currentDataService
            let feed = dataService.findOrCreateFeed(url: importableFeed.url).wait()!

            self.dataServiceFactory.currentDataService.updateFeed(feed, info: importableFeed).map { res -> Void in
                switch res {
                case .success():
                    updatedFeeds.append(feed)
                    break
                case .failure(_):
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
        let promise = feedCallback.promise
        self.workerQueue.addOperation {
            _ = self.dataServiceFactory.currentDataService.updateFeed(feed, info: singleFeed).then { _ in
                if feed.image == nil, let imageUrl = singleFeed.imageURL, !imageUrl.absoluteString.isEmpty {
                    self.callbacksInProgress[imageUrl] = feedCallback
                    self.downloadURL(imageUrl)
                } else {
                    promise.resolve(.success(feed))
                }
            }.wait()
        }
    }

    func didDownloadImage(_ image: Image, url: URL) {
        guard let imageCallback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValue(forKey: url)
        let feed = imageCallback.feed
        let promise = imageCallback.promise
        feed.image = image
        self.workerQueue.addOperation {
            _ = self.dataServiceFactory.currentDataService.saveFeed(feed).then { _ in
                promise.resolve(.success(feed))
            }
        }
    }

    func didDownloadData(_ data: Data, url: URL) {
        let error = NSError(domain: "com.rachelbrindle.Tethys.parseError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to parse data"])
        self.didFailToDownloadDataFromUrl(url, error: error)
    }

    func didFailToDownloadDataFromUrl(_ url: URL, error: Error?) {
        guard let _ = error, let callback = self.callbacksInProgress[url] else { return }
        self.callbacksInProgress.removeValue(forKey: url)
        let feed = callback.feed
        let promise = callback.promise
        self.workerQueue.addOperation {
            if url != feed.url {
                promise.resolve(.success(feed))
            } else {
                promise.resolve(.failure(TethysError.network(url, .unknown)))
            }
        }
    }

    // MARK: Private

    private func downloadURL(_ url: URL) {
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        self.urlSession.downloadTask(with: request).resume()
    }
}
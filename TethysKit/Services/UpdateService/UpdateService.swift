import Foundation
import Muon
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

protocol UpdateService: class {
    func updateFeed(_ feed: TethysKit.Feed) -> Future<Result<TethysKit.Feed, TethysError>>
}

final class OldUpdateService: UpdateService, NetworkClientDelegate {
    private let dataServiceFactory: DataServiceFactoryType
    private let urlSession: URLSession
    private let workerQueue: OperationQueue

    private var callbacksInProgress: [URL: (feed: TethysKit.Feed,
        promise: Promise<Result<TethysKit.Feed, TethysError>>)] = [:]

    init(dataServiceFactory: DataServiceFactoryType,
         urlSession: URLSession,
         urlSessionDelegate: TethysKitURLSessionDelegate,
         workerQueue: OperationQueue) {
        self.dataServiceFactory = dataServiceFactory
        self.urlSession = urlSession
        self.workerQueue = workerQueue
        urlSessionDelegate.delegate = self
    }

    func updateFeed(_ feed: Feed) -> Future<Result<TethysKit.Feed, TethysError>> {
        let promise = Promise<Result<TethysKit.Feed, TethysError>>()
        self.callbacksInProgress[feed.url] = (feed, promise)
        self.downloadURL(feed.url)
        return promise.future
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
        guard error != nil, let callback = self.callbacksInProgress[url] else { return }
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

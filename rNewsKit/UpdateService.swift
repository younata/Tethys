import Foundation
import Muon

protocol NetworkClientDelegate: class {
    func didDownloadImage(image: Image, url: NSURL)
    func didDownloadFeed(feed: Muon.Feed, url: NSURL)
    func didDownloadData(data: NSData, url: NSURL)
    func didFailToDownloadDataFromUrl(url: NSURL)
}

class URLSessionDelegate: NSObject, NSURLSessionDownloadDelegate {
    weak var delegate: NetworkClientDelegate?

    func URLSession(_ : NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL url: NSURL) {
        guard let data = NSData(contentsOfURL: url) else { return }
        let originalUrl = downloadTask.originalRequest?.URL ?? NSURL()
        if downloadTask.response?.MIMEType?.hasPrefix("image") == true, let image = Image(data: data) {
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
        self.delegate?.didFailToDownloadDataFromUrl(url)
    }
}

protocol UpdateServiceType: class {
    func updateFeed(feed: Feed, callback: Feed -> Void)
}

class UpdateService: UpdateServiceType, NetworkClientDelegate {
    private let dataService: DataService
    private let urlSession: NSURLSession

    private var feedsInProgress: [NSURL: (feed: Feed, callback: (Feed -> Void))] = [:]
    private var imagesInProgress: [NSURL: (feed: Feed, callback: (Feed -> Void))] = [:]

    init(dataService: DataService, urlSession: NSURLSession) {
        self.dataService = dataService
        self.urlSession = urlSession
    }

    func updateFeed(feed: Feed, callback: Feed -> Void) {
        guard let url = feed.url else {
            callback(feed)
            return
        }
        self.feedsInProgress[url] = (feed, callback)
        self.urlSession.downloadTaskWithURL(url).resume()
    }

    // MARK: NetworkClientDelegate

    func didDownloadFeed(muonFeed: Muon.Feed, url: NSURL) {
        guard let feedCallback = self.feedsInProgress[url] else { return }
        self.feedsInProgress.removeValueForKey(url)
        let feed = feedCallback.feed
        let callback = feedCallback.callback
        self.dataService.updateFeed(feed, info: muonFeed) {
            if feed.image == nil, let imageUrl = muonFeed.imageURL where !imageUrl.absoluteString.isEmpty {
                self.imagesInProgress[imageUrl] = feedCallback
                self.urlSession.downloadTaskWithURL(imageUrl).resume()
            } else {
                callback(feed)
            }
        }
    }

    func didDownloadImage(image: Image, url: NSURL) {
        guard let imageCallback = self.imagesInProgress[url] else { return }
        self.imagesInProgress.removeValueForKey(url)
        let feed = imageCallback.feed
        let callback = imageCallback.callback
        feed.image = image
        self.dataService.saveFeed(feed) {
            callback(feed)
        }
    }

    func didDownloadData(data: NSData, url: NSURL) {}

    func didFailToDownloadDataFromUrl(url: NSURL) {}
}

import Foundation
import Muon

protocol NetworkClientDelegate: class {
    func didDownloadImage(image: Image, url: NSURL)
    func didDownloadFeed(feed: Muon.Feed, url: NSURL)
    func didDownloadData(data: NSData, url: NSURL)
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
}

class UpdateService: NetworkClientDelegate {
    private let dataService: DataService
    private let urlSession: NSURLSession

    private var feedsInProgress: [NSURL: (feed: Feed, callback: (Feed -> Void))] = [:]

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
        let feed = feedCallback.feed
        let callback = feedCallback.callback
        self.dataService.updateFeed(feed, info: muonFeed) {
            callback(feed)
        }
    }

    func didDownloadImage(image: Image, url: NSURL) {}
    func didDownloadData(data: NSData, url: NSURL) {}
}

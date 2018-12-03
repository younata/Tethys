import Foundation
import Lepton
import CBGPromise
import Result

public protocol OPMLService {
    func importOPML(_ opml: URL) -> Future<Result<AnyCollection<Feed>, TethysError>>
    func writeOPML() -> Future<Result<URL, TethysError>>
}

final class LeptonOPMLService: NSObject, OPMLService {
    private let feedService: FeedService
    private let mainQueue: OperationQueue
    private let workQueue: OperationQueue

    init(feedService: FeedService, mainQueue: OperationQueue, importQueue: OperationQueue) {
        self.feedService = feedService
        self.mainQueue = mainQueue
        self.workQueue = importQueue

        super.init()
    }

    private func feedAlreadyExists(_ existingFeeds: [Feed], item: Lepton.Item) -> Bool {
        return existingFeeds.filter({
            let titleMatches = item.title == $0.title
            let tagsMatches = item.tags == $0.tags
            let urlMatches: Bool
            if let urlString = item.xmlURL {
                urlMatches = URL(string: urlString) == $0.url
            } else {
                urlMatches = false
            }
            return titleMatches && tagsMatches && urlMatches
        }).isEmpty == false
    }

    func importOPML(_ opml: URL) -> Future<Result<AnyCollection<Feed>, TethysError>> {
        let promise = Promise<Result<AnyCollection<Feed>, TethysError>>()
        let text: String
        do {
            text = try String(contentsOf: opml, encoding: String.Encoding.utf8)
        } catch let error {
            dump(error)
            promise.resolve(.failure(.unknown))
            return promise.future
        }
        let parser = Lepton.Parser(text: text)

        _ = parser.success {items in
            let futures = items.compactMap { URL(string: $0.xmlURL ?? "") }.map { self.feedService.subscribe(to: $0) }
            Promise<Result<Feed, TethysError>>.when(futures).then { results in
                let feeds = results.compactMap { $0.value }

                self.mainQueue.addOperation {
                    guard feeds.isEmpty else {
                        promise.resolve(.success(AnyCollection(feeds)))
                        return
                    }
                    promise.resolve(.failure(TethysError.multiple(results.compactMap { $0.error })))
                }
            }
        }
        _ = parser.failure { error in
            dump(error)
            self.mainQueue.addOperation {
                promise.resolve(.failure(.unknown))
            }
        }

        self.workQueue.addOperation(parser)

        return promise.future
    }

    private func generateOPMLContents(_ feeds: AnyCollection<Feed>) -> String {
        func sanitize(_ str: String?) -> String {
            if str == nil {
                return ""
            }
            var s = str!
            s = s.replacingOccurrences(of: "\"", with: "&quot;")
            s = s.replacingOccurrences(of: "'", with: "&apos;")
            s = s.replacingOccurrences(of: "<", with: "&gt;")
            s = s.replacingOccurrences(of: ">", with: "&lt;")
            s = s.replacingOccurrences(of: "&", with: "&amp;")
            return s
        }

        var ret = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n"
        ret += "<opml version=\"2.0\">\n    <body>\n"
        for feed in feeds {
            let title = "title=\"\(sanitize(feed.title))\""
            let url = "xmlUrl=\"\(sanitize(feed.url.absoluteString))\""
            let tags: String
            if feed.tags.count != 0 {
                let tagsList: String = feed.tags.joined(separator: ",")
                tags = "tags=\"\(tagsList)\""
            } else {
                tags = ""
            }
            let line = "<outline \(url) \(title) \(tags) type=\"rss\"/>"
            ret += "        \(line)\n"
        }
        ret += "    </body>\n</opml>"
        return ret
    }

    func writeOPML() -> Future<Result<URL, TethysError>> {
        return self.feedService.feeds().map { result -> Result<URL, TethysError> in
            switch result {
            case let .success(feeds):
                let opmlString = self.generateOPMLContents(feeds)
                let url: URL
                if #available(iOS 10.0, *) {
                    url = FileManager.default.temporaryDirectory.appendingPathComponent("Export OPML.opml")
                } else {
                    url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                        .appendingPathComponent("Export OPML.opml")
                }
                do {
                    try opmlString.write(to: url, atomically: true, encoding: String.Encoding.utf8)
                    return Result<URL, TethysError>.success(url)
                } catch {
                    return Result<URL, TethysError>.failure(.unknown)
                }
            case let .failure(error):
                return Result<URL, TethysError>.failure(error)
            }
        }
    }
}

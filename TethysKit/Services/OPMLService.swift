import Foundation
import Ra
import Lepton
import CBGPromise
import Result

public protocol OPMLService {
    func importOPML(_ opml: URL, completion: @escaping ([Feed]) -> Void)
    func writeOPML() -> Future<Result<URL, TethysError>>
}

final class DefaultOPMLService: NSObject, OPMLService, Injectable {
    private let dataRepository: DefaultDatabaseUseCase
    private let mainQueue: OperationQueue
    private let importQueue: OperationQueue

    required init(injector: Injector) {
        self.dataRepository = injector.create(DefaultDatabaseUseCase.self)!
        self.mainQueue = injector.create(kMainQueue, type: OperationQueue.self)!
        self.importQueue = injector.create(kBackgroundQueue, type: OperationQueue.self)!

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

    func importOPML(_ opml: URL, completion: @escaping ([Feed]) -> Void) {
        _ = dataRepository.feeds().then {
            guard case let Result.success(existingFeeds) = $0 else { return }
            do {
                let text = try String(contentsOf: opml, encoding: String.Encoding.utf8)
                let parser = Lepton.Parser(text: text)
                _ = parser.success {items in
                    var feeds: [Feed] = []

                    var feedCount = 0

                    let isComplete = {
                        if feeds.count == feedCount {
                            self.dataRepository.updateFeeds { _ in
                                self.mainQueue.addOperation {
                                    completion(feeds)
                                }
                            }
                        }
                    }

                    for item in items {
                        if self.feedAlreadyExists(existingFeeds, item: item) {
                            continue
                        }
                        if let feedURLString = item.xmlURL, let feedURL = URL(string: feedURLString) {
                            feedCount += 1
                            _ = self.dataRepository.newFeed(url: feedURL) { newFeed in
                                for tag in item.tags {
                                    newFeed.addTag(tag)
                                }
                                feeds.append(newFeed)
                                isComplete()
                            }
                        }
                    }
                }
                _ = parser.failure { _ in
                    self.mainQueue.addOperation {
                        completion([])
                    }
                }

                self.importQueue.addOperation(parser)
            } catch _ {
                completion([])
            }
        }
    }

    private func generateOPMLContents(_ feeds: [Feed]) -> String {
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
        return self.dataRepository.feeds().map { result -> Result<URL, TethysError> in
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

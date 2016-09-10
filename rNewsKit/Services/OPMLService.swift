import Foundation
import Ra
import Lepton
import Result

public final class OPMLService: NSObject, Injectable {
    private let dataRepository: DefaultDatabaseUseCase?
    private let mainQueue: OperationQueue?
    private let importQueue: OperationQueue?

    required public init(injector: Injector) {
        self.dataRepository = injector.create(kind: DefaultDatabaseUseCase.self)
        self.mainQueue = injector.create(string: kMainQueue) as? OperationQueue
        self.importQueue = injector.create(string: kBackgroundQueue) as? OperationQueue

        super.init()

        self.dataRepository?.addSubscriber(self)
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

    public func importOPML(_ opml: URL, completion: @escaping ([Feed]) -> Void) {
        guard let dataRepository = self.dataRepository else {
            completion([])
            return
        }
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
                            dataRepository.updateFeeds { _ in
                                self.mainQueue?.addOperation {
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
                            _ = dataRepository.newFeed { newFeed in
                                newFeed.url = feedURL
                                for tag in item.tags {
                                    newFeed.addTag(tag)
                                }
                                feeds.append(newFeed)
                                isComplete()
                            }
                        }
                    }
                }
                _ = parser.failure {error in
                    self.mainQueue?.addOperation {
                        completion([])
                    }
                }

                self.importQueue?.addOperation(parser)
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

    public func writeOPML() {
        let opmlLocation = documentsDirectory() + "/rnews.opml"
        _ = self.dataRepository?.feeds().then {
            guard case let Result.success(feeds) = $0 else { return }
            do {
                try self.generateOPMLContents(feeds).write(toFile: opmlLocation, atomically: true,
                    encoding: String.Encoding.utf8)
            } catch _ {}
        }.wait()
    }
}

extension OPMLService: DataSubscriber {
    public func markedArticles(_ articles: [Article], asRead read: Bool) {}
    public func deletedArticle(_ article: Article) {}
    public func willUpdateFeeds() {}
    public func didUpdateFeedsProgress(_ finished: Int, total: Int) {}
    public func deletedFeed(_ feed: Feed, feedsLeft: Int) {}

    public func didUpdateFeeds(_ feeds: [Feed]) {
        self.writeOPML()
    }
}

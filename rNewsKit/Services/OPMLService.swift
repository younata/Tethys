import Foundation
import Ra
import Lepton
import Result

public class OPMLService: NSObject, Injectable {
    private let dataRepository: DefaultDatabaseUseCase?
    private let mainQueue: NSOperationQueue?
    private let importQueue: NSOperationQueue?

    required public init(injector: Injector) {
        self.dataRepository = injector.create(DefaultDatabaseUseCase)
        self.mainQueue = injector.create(kMainQueue) as? NSOperationQueue
        self.importQueue = injector.create(kBackgroundQueue) as? NSOperationQueue

        super.init()

        self.dataRepository?.addSubscriber(self)
    }

    private func feedAlreadyExists(existingFeeds: [Feed], item: Lepton.Item) -> Bool {
        return existingFeeds.filter({
            let titleMatches = item.title == $0.title
            let tagsMatches = (item.tags ?? []) == $0.tags
            let urlMatches: Bool
            if let urlString = item.xmlURL {
                urlMatches = NSURL(string: urlString) == $0.url
            } else {
                urlMatches = false
            }
            return titleMatches && tagsMatches && urlMatches
        }).isEmpty == false
    }

    public func importOPML(opml: NSURL, completion: ([Feed]) -> Void) {
        guard let dataRepository = self.dataRepository else {
            completion([])
            return
        }
        dataRepository.feeds().then {
            guard case let Result.Success(existingFeeds) = $0 else { return }
            do {
                let text = try String(contentsOfURL: opml, encoding: NSUTF8StringEncoding)
                let parser = Lepton.Parser(text: text)
                parser.success {items in
                    var feeds: [Feed] = []

                    var feedCount = 0

                    let isComplete = {
                        if feeds.count == feedCount {
                            dataRepository.updateFeeds { _ in
                                self.mainQueue?.addOperationWithBlock {
                                    completion(feeds)
                                }
                            }
                        }
                    }

                    for item in items {
                        if self.feedAlreadyExists(existingFeeds, item: item) {
                            continue
                        }
                        if let feedURLString = item.xmlURL, feedURL = NSURL(string: feedURLString) {
                            feedCount += 1
                            dataRepository.newFeed { newFeed in
                                newFeed.url = feedURL
                                for tag in item.tags ?? [] {
                                    newFeed.addTag(tag)
                                }
                                feeds.append(newFeed)
                                isComplete()
                            }
                        }
                    }
                }
                parser.failure {error in
                    self.mainQueue?.addOperationWithBlock {
                        completion([])
                    }
                }

                self.importQueue?.addOperation(parser)
            } catch _ {
                completion([])
            }
        }
    }

    private func generateOPMLContents(feeds: [Feed]) -> String {
        func sanitize(str: String?) -> String {
            if str == nil {
                return ""
            }
            var s = str!
            s = s.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
            s = s.stringByReplacingOccurrencesOfString("'", withString: "&apos;")
            s = s.stringByReplacingOccurrencesOfString("<", withString: "&gt;")
            s = s.stringByReplacingOccurrencesOfString(">", withString: "&lt;")
            s = s.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
            return s
        }

        var ret = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n"
        ret += "<opml version=\"2.0\">\n    <body>\n"
        for feed in feeds {
            let title = "title=\"\(sanitize(feed.title))\""
            let url = "xmlUrl=\"\(sanitize(feed.url.absoluteString))\""
            let tags: String
            if feed.tags.count != 0 {
                let tagsList: String = feed.tags.joinWithSeparator(",")
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
        let opmlLocation = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
        self.dataRepository?.feeds().then {
            guard case let Result.Success(feeds) = $0 else { return }
            do {
                try self.generateOPMLContents(feeds).writeToFile(opmlLocation, atomically: true,
                    encoding: NSUTF8StringEncoding)
            } catch _ {}
        }
    }
}

extension OPMLService: DataSubscriber {
    public func markedArticles(articles: [Article], asRead read: Bool) {}
    public func deletedArticle(article: Article) {}
    public func willUpdateFeeds() {}
    public func didUpdateFeedsProgress(finished: Int, total: Int) {}
    public func deletedFeed(feed: Feed, feedsLeft: Int) {}

    public func didUpdateFeeds(feeds: [Feed]) {
        self.writeOPML()
    }
}

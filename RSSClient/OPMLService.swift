import Foundation
import Ra
import Lepton

public class OPMLService: NSObject, Injectable {
    private let dataRepository: DataRepository?
    private let mainQueue: NSOperationQueue?
    private let importQueue: NSOperationQueue?
    private let dataService: DataService?

    required public init(injector: Injector) {
        self.dataRepository = injector.create(DataRepository)
        self.mainQueue = injector.create(kMainQueue) as? NSOperationQueue
        self.importQueue = injector.create(kBackgroundQueue) as? NSOperationQueue
        self.dataService = injector.create(DataService)

        super.init()

        self.dataRepository?.addSubscriber(self)
    }

    private func feedAlreadyExists(existingFeeds: [Feed], item: Lepton.Item) -> Bool {
        return existingFeeds.filter({
            let titleMatches = item.title == $0.title
            let queryMatches = item.query == $0.query
            let tagsMatches = (item.tags ?? []) == $0.tags
            let urlMatches: Bool
            if let urlString = item.xmlURL {
                urlMatches = NSURL(string: urlString) == $0.url
            } else {
                urlMatches = $0.url == nil
            }
            return titleMatches && queryMatches && tagsMatches && urlMatches
        }).isEmpty == false
    }

    public func importOPML(opml: NSURL, completion: ([Feed]) -> Void) {
        guard let dataRepository = self.dataRepository, let dataService = self.dataService else {
            completion([])
            return
        }
        dataRepository.feeds {existingFeeds in
            do {
                let text = try String(contentsOfURL: opml, encoding: NSUTF8StringEncoding)
                let parser = Lepton.Parser(text: text)
                parser.success {items in
                    var feeds: [Feed] = []

                    for item in items {
                        if self.feedAlreadyExists(existingFeeds, item: item) {
                            continue
                        }
                        if item.isQueryFeed() {
                            if let title = item.title, let query = item.query {
                                dataService.createFeed { newFeed in
                                    newFeed.title = title
                                    newFeed.query = query
                                    newFeed.summary = item.summary ?? ""
                                    for tag in (item.tags ?? []) {
                                        newFeed.addTag(tag)
                                    }
                                    feeds.append(newFeed)
                                }
                            }
                        } else {
                            if let feedURL = item.xmlURL {
                                dataService.createFeed { newFeed in
                                    newFeed.url = NSURL(string: feedURL)
                                    for tag in item.tags ?? [] {
                                        newFeed.addTag(tag)
                                    }
                                    feeds.append(newFeed)
                                }
                            }
                        }
                    }
                    self.mainQueue?.addOperationWithBlock {
                        completion(feeds)
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
        for feed in feeds.filter({return $0.query == nil}) {
            let title = "title=\"\(sanitize(feed.title))\""
            let url = "xmlUrl=\"\(sanitize(feed.url?.absoluteString))\""
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
        self.dataRepository?.feeds {feeds in
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

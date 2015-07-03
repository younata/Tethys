import Foundation
import CoreData

#if os(iOS)
    public typealias Image=UIImage
#else
    public typealias Image=NSImage
#endif

public class Feed: Equatable, Hashable, CustomStringConvertible {
    public var title: String {
        willSet {
            if newValue != title {
                self.updated = true
            }
        }
    }
    public var url: NSURL? {
        willSet {
            if newValue != url {
                self.updated = true
            }
        }
    }
    public var summary: String {
        willSet {
            if newValue != summary {
                self.updated = true
            }
        }
    }
    public var query: String? {
        willSet {
            if newValue != query {
                self.updated = true
            }
        }
    }
    public private(set) var tags: [String]
    public var waitPeriod: Int? {
        willSet {
            if newValue != waitPeriod {
                self.updated = true
            }
        }
    }
    public var remainingWait: Int? {
        willSet {
            if newValue != remainingWait {
                self.updated = true
            }
        }
    }
    public private(set) var articles: [Article] = []
    public var image: Image? {
        willSet {
            if newValue != image {
                self.updated = true
            }
        }
    }

    public private(set) var identifier: String

    public var isQueryFeed: Bool { return query != nil }

    public var hashValue: Int {
        if let id = feedID {
            return id.URIRepresentation().hash
        }
        let nonNilHashValues = title.hashValue ^ summary.hashValue
        let possiblyNilHashValues: Int
        if let link = url, query = query, waitPeriod = waitPeriod,
            remainingWait = remainingWait, image = image {
                possiblyNilHashValues = link.hash ^ query.hashValue ^
                    waitPeriod.hashValue ^ remainingWait.hashValue ^ image.hash
        } else {
            possiblyNilHashValues = 0
        }
        let tagsHashValues = tags.map({$0.hashValue}).reduce(0, combine: ^)
        return nonNilHashValues ^ possiblyNilHashValues ^ tagsHashValues
    }

    public var description: String {
        return "Feed: title: \(title), url: \(url), summary: \(summary), query: \(query), tags: \(tags)\n"
    }

    public private(set) var updated = false

    public func waitPeriodInRefreshes() -> Int {
        var ret = 0, next = 1
        if let waitPeriod = waitPeriod {
            let wait = max(0, waitPeriod - 2)
            for _ in 0..<wait {
                (ret, next) = (next, ret+next)
            }
        }
        return ret
    }

    public func unreadArticles() -> [Article] {
        return articles.filter { !$0.read }
    }

    public func addArticle(article: Article) {
        if !self.articles.contains(article) {
            updated = true
            articles.append(article)
            if let otherFeed = article.feed where otherFeed != self {
                otherFeed.removeArticle(article)
            }
            article.feed = self
        }
    }

    public func removeArticle(article: Article) {
        if self.articles.contains(article) {
            updated = true
            self.articles = self.articles.filter { $0 != article }
            if article.feed == self {
                article.feed = nil
            }
        }
    }

    public func addTag(tag: String) {
        if !tags.contains(tag) {
            updated = true
            tags.append(tag)
        }
    }

    public func removeTag(tag: String) {
        if tags.contains(tag) {
            updated = true
            tags = tags.filter { $0 != tag }
        }
    }

    public init(title: String, url: NSURL?, summary: String, query: String?, tags: [String],
        waitPeriod: Int?, remainingWait: Int?, articles: [Article], image: Image?, identifier: String = "") {
            self.title = title
            self.url = url
            self.summary = summary
            self.query = query
            self.tags = tags
            self.waitPeriod = waitPeriod
            self.remainingWait = remainingWait
            self.image = image
            self.articles = articles
            self.identifier = identifier
            for article in articles {
                article.feed = self
            }
    }

    public private(set) var feedID: NSManagedObjectID? = nil

    internal init(feed: CoreDataFeed) {
        title = feed.title ?? ""
        let url: NSURL?
        if let feedURL = feed.url {
            url = NSURL(string: feedURL)
        } else {
            url = nil
        }
        self.url = url
        summary = feed.summary ?? ""
        query = feed.query
        tags = feed.tags
        waitPeriod = feed.waitPeriod
        remainingWait = feed.remainingWait
        self.identifier = feed.objectID.URIRepresentation().description

        let articlesList = Array(feed.articles)
        articles = articlesList.map { Article(article: $0, feed: self) }
        image = feed.image as? Image

        feedID = feed.objectID
    }
}

public func ==(a: Feed, b: Feed) -> Bool {
    if let aID = a.feedID, let bID = b.feedID {
        return aID.URIRepresentation() == bID.URIRepresentation()
    }
    return a.title == b.title && a.url == b.url && a.summary == b.summary &&
        a.query == b.query && a.tags == b.tags && a.waitPeriod == b.waitPeriod &&
        a.remainingWait == b.remainingWait && a.image == b.image
}

import Foundation
import CoreData
import JavaScriptCore

#if os(iOS)
    import UIKit
    public typealias Image=UIImage
#else
    import Cocoa
    public typealias Image=NSImage
#endif

@objc public protocol FeedJSExport: JSExport {
    var title: String { get set }
    var displayTitle: String { get }
    var url: NSURL? { get set }
    var summary: String { get set }
    var displaySummary: String { get }
    var query: String? { get set }
    var tags: [String] { get }
    var waitPeriod: Int { get set }
    var remainingWait: Int { get set }
    var articles: [Article] { get }
    var identifier: String { get }
    var isQueryFeed: Bool { get }
}

@objc public class Feed: NSObject, FeedJSExport {
    dynamic public var title: String {
        willSet {
            if newValue != title {
                self.updated = true
            }
        }
    }

    public var displayTitle: String {
        if let tagTitle = self.tags.filter({$0.hasPrefix("~")}).last {
            return tagTitle.substringFromIndex(tagTitle.startIndex.successor())
        }
        return self.title
    }

    dynamic public var url: NSURL? {
        willSet {
            if newValue != url {
                self.updated = true
            }
        }
    }
    dynamic public var summary: String {
        willSet {
            if newValue != summary {
                self.updated = true
            }
        }
    }

    public var displaySummary: String {
        if let tagSummary = self.tags.filter({$0.hasPrefix("_")}).last {
            return tagSummary.substringFromIndex(tagSummary.startIndex.successor())
        }
        return self.summary
    }

    dynamic public var query: String? {
        willSet {
            if newValue != query {
                self.updated = true
            }
        }
    }
    dynamic public private(set) var tags: [String]
    dynamic public var waitPeriod: Int {
        willSet {
            if newValue != waitPeriod {
                self.updated = true
            }
        }
    }
    dynamic public var remainingWait: Int {
        willSet {
            if newValue != remainingWait {
                self.updated = true
            }
        }
    }

    @available(*, deprecated=1.0, renamed="articlesArray")
    dynamic public var articles: [Article] { return Array(self.articlesArray) }

    public private(set) var articlesArray: CoreDataBackedArray<Article>

    public var image: Image? {
        willSet {
            if newValue != image {
                self.updated = true
            }
        }
    }

    dynamic public private(set) var identifier: String

    dynamic public var isQueryFeed: Bool { return query != nil }

    public override var hashValue: Int {
        if let id = feedID {
            return id.URIRepresentation().hash
        }
        let nonNilHashValues = title.hashValue ^ summary.hashValue ^ waitPeriod.hashValue ^ remainingWait.hashValue
        let possiblyNilHashValues: Int
        if let link = url, query = query, image = image {
                possiblyNilHashValues = link.hash ^ query.hashValue ^ image.hash
        } else {
            possiblyNilHashValues = 0
        }
        let tagsHashValues = tags.map({$0.hashValue}).reduce(0, combine: ^)
        return nonNilHashValues ^ possiblyNilHashValues ^ tagsHashValues
    }

    public override var description: String {
        return "Feed: title: \(title), url: \(url), summary: \(summary), query: \(query), tags: \(tags)\n"
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        guard let b = object as? Feed else {
            return false
        }
        if let aID = self.feedID, let bID = b.feedID {
            return aID.URIRepresentation() == bID.URIRepresentation()
        }
        return self.title == b.title && self.url == b.url && self.summary == b.summary &&
            self.query == b.query && self.tags == b.tags && self.waitPeriod == b.waitPeriod &&
            self.remainingWait == b.remainingWait && self.image == b.image && self.articlesArray == b.articlesArray
    }

    public private(set) var updated = false

    public func waitPeriodInRefreshes() -> Int {
        var ret = 0, next = 1
        let wait = max(0, waitPeriod - 2)
        for _ in 0..<wait {
            (ret, next) = (next, ret+next)
        }
        return ret
    }

    public func unreadArticles() -> CoreDataBackedArray<Article> {
        return self.articlesArray.filterWithPredicate(NSPredicate(format: "read == %@", false))
    }

    public func addArticle(article: Article) {
        if !self.articlesArray.contains(article) {
            self.articlesArray.append(article)
            if !self.isQueryFeed {
                self.updated = true
                if let otherFeed = article.feed where otherFeed != self {
                    otherFeed.removeArticle(article)
                }
                article.feed = self
            }
        }
    }

    public func removeArticle(article: Article) {
        if self.articlesArray.contains(article) {
            self.articlesArray.remove(article)
            if !self.isQueryFeed {
                self.updated = true
                if article.feed == self {
                    article.feed = nil
                }
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
        waitPeriod: Int, remainingWait: Int, articles: [Article], image: Image?, identifier: String = "") {
            self.title = title
            self.url = url
            self.summary = summary
            self.query = query
            self.tags = tags
            self.waitPeriod = waitPeriod
            self.remainingWait = remainingWait
            self.image = image
            self.articlesArray = CoreDataBackedArray(articles)
            self.identifier = identifier
            super.init()
            for article in articles {
                article.feed = self
            }
            self.updated = false
    }

    public private(set) var feedID: NSManagedObjectID? = nil

    internal init(feed: CoreDataFeed) {
        self.title = feed.title ?? ""
        let url: NSURL?
        if let feedURL = feed.url {
            url = NSURL(string: feedURL)
        } else {
            url = nil
        }
        self.url = url
        self.summary = feed.summary ?? ""
        self.query = feed.query
        self.tags = feed.tags
        self.waitPeriod = feed.waitPeriodInt
        self.remainingWait = feed.remainingWaitInt

        self.image = feed.image as? Image
        self.feedID = feed.objectID
        self.identifier = feedID?.URIRepresentation().absoluteString ?? ""
        self.articlesArray = CoreDataBackedArray<Article>()
        super.init()
        if !self.isQueryFeed {
            let sortByUpdated = NSSortDescriptor(key: "updatedAt", ascending: false)
            let sortByPublished = NSSortDescriptor(key: "published", ascending: false)
            self.articlesArray = CoreDataBackedArray(entityName: "Article", predicate: NSPredicate(format: "feed == %@", feed), managedObjectContext: feed.managedObjectContext!, conversionFunction: {
                return Article(article: $0 as! CoreDataArticle, feed: self)
                }, sortDescriptors: [sortByUpdated, sortByPublished])
        }

        self.updated = false
    }
}
import Foundation
import RealmSwift

#if os(iOS)
    import UIKit
    public typealias Image=UIImage
#else
    import Cocoa
    public typealias Image=NSImage
#endif

public final class Feed: Hashable, CustomStringConvertible {
    public var title: String {
        willSet {
            if newValue != title {
                self.updated = true
            }
        }
    }

    public var displayTitle: String {
        if let tagTitle = self.tags.objectPassingTest({$0.hasPrefix("~")}) {
            return tagTitle.substring(from: tagTitle.index(after: tagTitle.startIndex))
        }
        if self.title.isEmpty {
            return self.url.absoluteString
        }
        return self.title
    }

    public var url: URL {
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

    public var displaySummary: String {
        if let tagSummary = self.tags.objectPassingTest({$0.hasPrefix("`")}) {
            return tagSummary.substring(from: tagSummary.index(after: tagSummary.startIndex))
        }
        return self.summary
    }

    public var lastUpdated: Date {
        willSet {
            if newValue != lastUpdated {
                self.updated = true
            }
        }
    }

    public fileprivate(set) var tags: [String]
    public var waitPeriod: Int {
        willSet {
            if newValue != waitPeriod {
                self.updated = true
            }
        }
    }
    public internal(set) var remainingWait: Int {
        willSet {
            if newValue != remainingWait {
                self.updated = true
            }
        }
    }

    public var settings: Settings? {
        willSet {
            if newValue != settings {
                self.updated = true
            }
        }
    }

    @available(*, deprecated, message: "Query a service for the articles")
    public internal(set) var articlesArray: DataStoreBackedArray<Article>

    public internal(set) var image: Image? {
        willSet {
            if newValue != image {
                self.updated = true
            }
        }
    }

    public private(set) var identifier: String

    public var hashValue: Int {
        if let id = feedID as? String {
            return id.hash
        }
        let nonNilHashValues = title.hashValue ^ url.hashValue ^ summary.hashValue ^
            waitPeriod.hashValue ^ remainingWait.hashValue
        let possiblyNilHashValues: Int
        if let image = image {
                possiblyNilHashValues = image.hash
        } else {
            possiblyNilHashValues = 0
        }
        let tagsHashValues = tags.map({$0.hashValue}).reduce(0, ^)
        return nonNilHashValues ^ possiblyNilHashValues ^ tagsHashValues
    }

    public var description: String {
        return "Feed: title: \(title), url: \(url), summary: \(summary), tags: \(tags)\n"
    }

    public func isEqual(_ object: AnyObject?) -> Bool {
        guard let b = object as? Feed else {
            return false
        }
        if let aID = self.feedID as? URL, let bID = b.feedID as? URL {
            return aID == bID
        }
        return self.title == b.title && self.url == b.url && self.summary == b.summary && self.tags == b.tags &&
            self.waitPeriod == b.waitPeriod && self.remainingWait == b.remainingWait && self.image == b.image
    }

    public private(set) var updated = false

    @available(*, deprecated, message: "Query a service for the unread articles")
    public private(set) lazy var unreadArticles: DataStoreBackedArray<Article> = {
        return self.articlesArray.filterWithPredicate(NSPredicate(format: "read == %@", false as CVarArg))
    }()

    @available(*, deprecated, message: "Don't use the feed object to add articles")
    public func addArticle(_ article: Article) {
        if !self.articlesArray.contains(article) {
            self.articlesArray.append(article)
            self.updated = true
            if let otherFeed = article.feed, otherFeed != self {
                otherFeed.removeArticle(article)
            }
            article.feed = self
        }
    }

    @available(*, deprecated, message: "Don't use the feed object to remove articles")
    public func removeArticle(_ article: Article) {
        if self.articlesArray.contains(article) {
            _ = self.articlesArray.remove(article)
            self.updated = true
            if article.feed == self {
                article.feed = nil
            }
        }
    }

    public func addTag(_ tag: String) {
        if !tags.contains(tag) {
            updated = true
            tags.append(tag)
        }
    }

    public func removeTag(_ tag: String) {
        if tags.contains(tag) {
            updated = true
            tags = tags.filter { $0 != tag }
        }
    }

    internal func resetUnreadArticles() {
        self.unreadArticles = self.articlesArray.filterWithPredicate(NSPredicate(format: "read == %@",
                                                                                 false as CVarArg))
    }

    internal func resetArticles(realm: Realm) {
        let sortByUpdated = NSSortDescriptor(key: "updatedAt", ascending: false)
        let sortByPublished = NSSortDescriptor(key: "published", ascending: false)

        self.articlesArray = DataStoreBackedArray<Article>(
            realmDataType: RealmArticle.self,
            predicate: NSPredicate(format: "feed.id == %@", self.identifier),
            realmConfiguration: realm.configuration,
            conversionFunction: { return Article(realmArticle: $0 as! RealmArticle, feed: self) },
            sortDescriptors: [sortByUpdated, sortByPublished]
        )
    }

    public init(title: String, url: URL, summary: String, tags: [String],
                waitPeriod: Int, remainingWait: Int, articles: [Article], image: Image?,
                lastUpdated: Date = Date(), identifier: String = "") {
        self.title = title
        self.url = url
        self.summary = summary
        self.tags = tags
        self.waitPeriod = waitPeriod
        self.remainingWait = remainingWait
        self.image = image
        self.articlesArray = DataStoreBackedArray(articles)
        self.lastUpdated = lastUpdated
        self.identifier = identifier

        for article in articles {
            article.feed = self
        }
        self.updated = false
    }

    public private(set) var feedID: AnyObject?

    internal init(realmFeed feed: RealmFeed) {
        self.title = feed.title ?? ""
        self.url = URL(string: feed.url)!
        self.summary = feed.summary ?? ""
        self.tags = feed.tags.map { $0.string }
        self.waitPeriod = feed.waitPeriod
        self.remainingWait = feed.remainingWait
        self.lastUpdated = feed.lastUpdated

        if let data = feed.imageData {
            self.image = Image(data: data)
        } else {
            self.image = nil
        }
        self.feedID = feed.id as AnyObject
        self.identifier = feed.id
        self.articlesArray = DataStoreBackedArray<Article>()
        if let realm = feed.realm {
            let sortByUpdated = NSSortDescriptor(key: "updatedAt", ascending: false)
            let sortByPublished = NSSortDescriptor(key: "published", ascending: false)

            self.articlesArray = DataStoreBackedArray<Article>(
                realmDataType: RealmArticle.self,
                predicate: NSPredicate(format: "feed.id == %@", feed.id),
                realmConfiguration: realm.configuration,
                conversionFunction: { return Article(realmArticle: $0 as! RealmArticle, feed: self) },
                sortDescriptors: [sortByUpdated, sortByPublished]
            )
        } else {
            let articles = feed.articles.map { Article(realmArticle: $0, feed: self) }
            self.articlesArray = DataStoreBackedArray(Array(articles))
        }

        if let settings = feed.settings {
            self.settings = Settings(realmSettings: settings)
        }

        self.updated = false
    }
}

public func == (lhs: Feed, rhs: Feed) -> Bool {
    return lhs.isEqual(rhs)
}

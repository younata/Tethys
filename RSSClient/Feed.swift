import Foundation

#if os(iOS)
    typealias Image=UIImage
#else
    typealias Image=NSImage
#endif

class Feed : Equatable, Hashable {
    var title : String {
        willSet {
            if newValue != title {
                self.updated = true
            }
        }
    }
    var url : NSURL? {
        willSet {
            if newValue != url {
                self.updated = true
            }
        }
    }
    var summary : String {
        willSet {
            if newValue != summary {
                self.updated = true
            }
        }
    }
    var query : String? {
        willSet {
            if newValue != query {
                self.updated = true
            }
        }
    }
    internal private(set) var tags : [String]
    var waitPeriod : Int? {
        willSet {
            if newValue != waitPeriod {
                self.updated = true
            }
        }
    }
    var remainingWait : Int? {
        willSet {
            if newValue != remainingWait {
                self.updated = true
            }
        }
    }
    internal private(set) var articles : [Article] = []
    var image : Image? {
        willSet {
            if newValue != image {
                self.updated = true
            }
        }
    }

    var isQueryFeed : Bool { return query != nil }

    var hashValue : Int {
        if let id = feedID {
            return id.URIRepresentation().hash
        }
        let nonNilHashValues = title.hashValue ^ summary.hashValue
        let possiblyNilHashValues : Int
        if let link = url, query = query, waitPeriod = waitPeriod,
            remainingWait = remainingWait, image = image {
                possiblyNilHashValues = link.hash ^ query.hashValue ^ waitPeriod.hashValue ^ remainingWait.hashValue ^ image.hash
        } else {
            possiblyNilHashValues = 0
        }
        let tagsHashValues = tags.map({$0.hashValue}).reduce(0, combine: ^)
        return nonNilHashValues ^ possiblyNilHashValues ^ tagsHashValues
    }

    internal private(set) var updated = false

    func waitPeriodInRefreshes() -> Int {
        var ret = 0, next = 1
        if let waitPeriod = waitPeriod {
            let wait = max(0, waitPeriod - 2)
            for i in 0..<wait {
                (ret, next) = (next, ret+next)
            }
        }
        return ret
    }

    func unreadArticles() -> [Article] {
        return []
    }

    func addArticle(article: Article) {
        if !contains(self.articles, article) {
            updated = true
            articles.append(article)
            if let otherFeed = article.feed where otherFeed != self {
                otherFeed.removeArticle(article)
            }
            article.feed = self
        }
    }

    func removeArticle(article: Article) {
        if contains(self.articles, article) {
            updated = true
            self.articles = self.articles.filter { $0 != article }
            if article.feed == self {
                article.feed = nil
            }
        }
    }

    func addTag(tag: String) {
        if !contains(tags, tag) {
            updated = true
            tags.append(tag)
        }
    }

    func removeTag(tag: String) {
        if contains(tags, tag) {
            updated = true
            tags = tags.filter { $0 != tag }
        }
    }

    init(title: String, url: NSURL?, summary: String, query: String?, tags: [String],
        waitPeriod: Int?, remainingWait: Int?, articles: [Article], image: Image?) {
            self.title = title
            self.url = url
            self.summary = summary
            self.query = query
            self.tags = tags
            self.waitPeriod = waitPeriod
            self.remainingWait = remainingWait
            self.image = image
            self.articles = articles
            for article in articles {
                article.feed = self
            }
    }

    private(set) var feedID : NSManagedObjectID? = nil

    init(feed: CoreDataFeed) {
        title = feed.title ?? ""
        let url : NSURL?
        if let feedURL = feed.url {
            url = NSURL(string: feedURL)
        } else {
            url = nil
        }
        summary = feed.summary ?? ""
        query = feed.query
        tags = feed.tags as? [String] ?? []
        waitPeriod = feed.waitPeriod?.integerValue
        remainingWait = feed.remainingWait?.integerValue
        if let feedArticles = feed.articles as? Set<CoreDataArticle> {
            let articlesList = Array(feedArticles)
            articles = articlesList.map { Article(article: $0, feed: self) }
        }
        image = feed.image as? Image

        feedID = feed.objectID
    }
}

func ==(a: Feed, b: Feed) -> Bool {
    if let aID = a.feedID, let bID = b.feedID {
        return aID.URIRepresentation() == bID.URIRepresentation()
    }
    return a.title == b.title && a.url == b.url && a.summary == b.summary &&
        a.query == b.query && a.tags == b.tags && a.waitPeriod == b.waitPeriod &&
        a.remainingWait == b.remainingWait && a.image == b.image
}

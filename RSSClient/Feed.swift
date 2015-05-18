import Foundation

#if os(iOS)
    typealias Image=UIImage
#else
    typealias Image=NSImage
#endif

class Feed : Equatable, Hashable {
    var title : String
    var url : NSURL?
    var summary : String
    var query : String?
    var tags : [String]
    var waitPeriod : Int?
    var remainingWait : Int?
    var articles : [Article] = []
    var image : Image?

    var isQueryFeed : Bool { return query != nil }

    var hashValue : Int {
        return 0
    }

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
            articles.append(article)
        }
    }

    func removeArticle(article: Article) {
        if contains(self.articles, article) {
            self.articles = self.articles.filter { $0 != article }
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
    return true
}

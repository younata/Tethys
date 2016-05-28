import CBGPromise
import Result

class InMemoryDataService: DataService {
    let mainQueue: NSOperationQueue
    let searchIndex: SearchIndex?

    init(mainQueue: NSOperationQueue, searchIndex: SearchIndex?) {
        self.mainQueue = mainQueue
        self.searchIndex = searchIndex
    }

    var feeds = [Feed]()
    var articles = [Article]()
    var enclosures = [Enclosure]()

    func createFeed(callback: Feed -> Void) {
        let feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0,
                        articles: [], image: nil)
        callback(feed)
        self.feeds.append(feed)
    }

    func createArticle(feed: Feed?, callback: Article -> Void) {
        let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil,
                              identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [],
                              enclosures: [])
        feed?.addArticle(article)
        callback(article)
        self.articles.append(article)
    }

    func createEnclosure(article: Article?, callback: Enclosure -> Void) {
        let enclosure = Enclosure(url: NSURL(), kind: "", article: article)
        article?.addEnclosure(enclosure)
        callback(enclosure)
        self.enclosures.append(enclosure)
    }

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, RNewsError>> {
        let promise = Promise<Result<DataStoreBackedArray<Feed>, RNewsError>>()
        promise.resolve(.Success(DataStoreBackedArray(self.feeds)))
        return promise.future
    }

    func articlesMatchingPredicate(predicate: NSPredicate) ->
        Future<Result<DataStoreBackedArray<Article>, RNewsError>> {
            let promise = Promise<Result<DataStoreBackedArray<Article>, RNewsError>>()
            promise.resolve(.Success(DataStoreBackedArray(self.articles.filter({ predicate.evaluateWithObject($0) }))))
            return promise.future
    }

    func deleteFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        if let index = self.feeds.indexOf(feed) {
            self.feeds.removeAtIndex(index)
        }
        for _ in 0..<feed.articlesArray.count {
            guard let article = feed.articlesArray.first else { break }
            self.deleteArticle(article)
            feed.removeArticle(article)
        }
        let promise = Promise<Result<Void, RNewsError>>()
        promise.resolve(.Success())
        return promise.future
    }

    func deleteArticle(article: Article) -> Future<Result<Void, RNewsError>> {
        if let index = self.articles.indexOf(article) {
            self.articles.removeAtIndex(index)
        }
        article.feed?.removeArticle(article)
        article.feed = nil
        for _ in 0..<article.enclosuresArray.count {
            guard let enclosure = article.enclosuresArray.first else { break }
            self.deleteEnclosure(enclosure)
            article.removeEnclosure(enclosure)
        }
        let promise = Promise<Result<Void, RNewsError>>()
        promise.resolve(.Success())
        return promise.future
    }

    func deleteEnclosure(enclosure: Enclosure) -> Future<Result<Void, RNewsError>> {
        if let index = self.enclosures.indexOf(enclosure) {
            self.enclosures.removeAtIndex(index)
        }
        enclosure.article?.removeEnclosure(enclosure)
        enclosure.article = nil
        let promise = Promise<Result<Void, RNewsError>>()
        promise.resolve(.Success())
        return promise.future
    }

    func batchCreate(feedCount: Int, articleCount: Int, enclosureCount: Int) ->
        Future<Result<([Feed], [Article], [Enclosure]), RNewsError>> {
            let promise = Promise<Result<([Feed], [Article], [Enclosure]), RNewsError>>()
            var feeds: [Feed] = []
            var articles: [Article] = []
            var enclosures: [Enclosure] = []
            for _ in 0..<feedCount {
                self.createFeed { feeds.append($0) }
            }
            for _ in 0..<articleCount {
                self.createArticle(nil) { articles.append($0) }
            }
            for _ in 0..<enclosureCount {
                self.createEnclosure(nil) { enclosures.append($0) }
            }

            let success = Result<([Feed], [Article], [Enclosure]), RNewsError>(value: (feeds, articles, enclosures))
            promise.resolve(success)
            return promise.future
    }

    func batchSave(feeds: [Feed], articles: [Article], enclosures: [Enclosure]) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        promise.resolve(.Success())
        return promise.future
    }

    func deleteEverything() -> Future<Result<Void, RNewsError>> {
        self.feeds = []
        self.articles = []
        self.enclosures = []

        let promise = Promise<Result<Void, RNewsError>>()
        promise.resolve(.Success())
        return promise.future
    }
}

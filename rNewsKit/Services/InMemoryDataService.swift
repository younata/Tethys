import CBGPromise
import Result

final class InMemoryDataService: DataService {
    let mainQueue: OperationQueue
    let searchIndex: SearchIndex?

    init(mainQueue: OperationQueue, searchIndex: SearchIndex?) {
        self.mainQueue = mainQueue
        self.searchIndex = searchIndex
    }

    var feeds = [Feed]()
    var articles = [Article]()

    func createFeed(_ callback: (Feed) -> Void) -> Future<Result<Feed, RNewsError>> {
        let feed = Feed(title: "", url: URL(string: "")! as NSURL, summary: "", tags: [], waitPeriod: 0, remainingWait: 0,
                        articles: [], image: nil)
        callback(feed)
        self.feeds.append(feed)
        let promise = Promise<Result<Feed, RNewsError>>()
        promise.resolve(.Success(feed))
        return promise.future
    }

    func createArticle(_ feed: Feed?, callback: (Article) -> Void) {
        let article = Article(title: "", link: nil, summary: "", authors: [], published: Date() as NSDate, updatedAt: nil,
                              identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [])
        feed?.addArticle(article)
        callback(article)
        self.articles.append(article)
    }

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, RNewsError>> {
        let promise = Promise<Result<DataStoreBackedArray<Feed>, RNewsError>>()
        promise.resolve(.Success(DataStoreBackedArray(self.feeds)))
        return promise.future
    }

    func articlesMatchingPredicate(_ predicate: NSPredicate) ->
        Future<Result<DataStoreBackedArray<Article>, RNewsError>> {
            let promise = Promise<Result<DataStoreBackedArray<Article>, RNewsError>>()
            promise.resolve(.Success(DataStoreBackedArray(self.articles.filter({ predicate.evaluateWithObject($0) }))))
            return promise.future
    }

    func deleteFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>> {
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

    func deleteArticle(_ article: Article) -> Future<Result<Void, RNewsError>> {
        if let index = self.articles.indexOf(article) {
            self.articles.removeAtIndex(index)
        }
        article.feed?.removeArticle(article)
        article.feed = nil
        let promise = Promise<Result<Void, RNewsError>>()
        promise.resolve(.Success())
        return promise.future
    }

    func batchCreate(_ feedCount: Int, articleCount: Int) ->
        Future<Result<([Feed], [Article]), RNewsError>> {
            let promise = Promise<Result<([Feed], [Article]), RNewsError>>()
            var feeds: [Feed] = []
            var articles: [Article] = []
            for _ in 0..<feedCount {
                self.createFeed { feeds.append($0) }
            }
            for _ in 0..<articleCount {
                self.createArticle(nil) { articles.append($0) }
            }

            let success = Result<([Feed], [Article]), RNewsError>(value: (feeds, articles))
            promise.resolve(success)
            return promise.future
    }

    func batchSave(_ feeds: [Feed], articles: [Article]) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        promise.resolve(.Success())
        return promise.future
    }

    func deleteEverything() -> Future<Result<Void, RNewsError>> {
        self.feeds = []
        self.articles = []

        let promise = Promise<Result<Void, RNewsError>>()
        promise.resolve(.Success())
        return promise.future
    }
}

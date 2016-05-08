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

    func feedsMatchingPredicate(predicate: NSPredicate, callback: DataStoreBackedArray<Feed> -> Void) {
        callback(DataStoreBackedArray(self.feeds.filter({ predicate.evaluateWithObject($0) })))
    }

    func articlesMatchingPredicate(predicate: NSPredicate, callback: DataStoreBackedArray<Article> -> Void) {
        callback(DataStoreBackedArray(self.articles.filter({ predicate.evaluateWithObject($0) })))
    }

    func enclosuresMatchingPredicate(predicate: NSPredicate, callback: DataStoreBackedArray<Enclosure> -> Void) {
        callback(DataStoreBackedArray(self.enclosures.filter({ predicate.evaluateWithObject($0) })))
    }

    func saveFeed(feed: Feed, callback: (Void) -> (Void)) {
        callback()
    }

    func saveArticle(article: Article, callback: (Void) -> (Void)) {
        callback()
    }

    func saveEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        callback()
    }

    func deleteFeed(feed: Feed, callback: (Void) -> (Void)) {
        if let index = self.feeds.indexOf(feed) {
            self.feeds.removeAtIndex(index)
        }
        for _ in 0..<feed.articlesArray.count {
            guard let article = feed.articlesArray.first else { break }
            self.deleteArticle(article, callback: {})
            feed.removeArticle(article)
        }
        callback()
    }

    func deleteArticle(article: Article, callback: (Void) -> (Void)) {
        if let index = self.articles.indexOf(article) {
            self.articles.removeAtIndex(index)
        }
        article.feed?.removeArticle(article)
        article.feed = nil
        for _ in 0..<article.enclosuresArray.count {
            guard let enclosure = article.enclosuresArray.first else { break }
            self.deleteEnclosure(enclosure, callback: {})
            article.removeEnclosure(enclosure)
        }
        callback()
    }

    func deleteEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        if let index = self.enclosures.indexOf(enclosure) {
            self.enclosures.removeAtIndex(index)
        }
        enclosure.article?.removeEnclosure(enclosure)
        enclosure.article = nil
        callback()
    }

    func batchCreate(feedCount: Int, articleCount: Int, enclosureCount: Int, callback: BatchCreateCallback) {
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

        callback(feeds, articles, enclosures)
    }

    func batchSave(feeds: [Feed], articles: [Article], enclosures: [Enclosure], callback: Void -> Void) {
        callback()
    }

    func batchDelete(feeds: [Feed], articles: [Article], enclosures: [Enclosure], callback: Void -> Void) {
        feeds.forEach { self.deleteFeed($0) {} }
        articles.forEach { self.deleteArticle($0) {} }
        enclosures.forEach { self.deleteEnclosure($0) {} }

        callback()
    }

    func deleteEverything(callback: Void -> Void) {
        self.feeds = []
        self.articles = []
        self.enclosures = []

        callback()
    }
}

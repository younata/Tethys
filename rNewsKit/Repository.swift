import CBGPromise

protocol Repository {

}

class DatabaseRepository: Repository {
    private let dataService: DataService
    private let scriptService: ScriptService
//    private let networkService: NetworkService

    init(dataService: DataService, scriptService: ScriptService) {
        self.dataService = dataService
        self.scriptService = scriptService
    }

    private var _feeds: [Feed]? = nil
    func feeds() -> Future<[Feed]> {
        if let feeds = self._feeds {
            let promise = Promise<[Feed]>()
            promise.resolve(feeds)
            return promise.future
        }
        return self.dataService.allFeeds().map { feedArray -> [Feed] in
            let unsorted = Array(feedArray)
            let feeds = unsorted.sort { return $0.displayTitle < $1.displayTitle }

            let nonQueryFeeds = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [] : [$1]) }
            let queryFeeds    = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [$1] : []) }
            for feed in queryFeeds {
                let articles = self.articlesMatchingQuery(feed.query!, feeds: nonQueryFeeds)
                articles.forEach { feed.addArticle($0) }
            }
            return feeds
        }
    }

    func articlesMatchingQuery(query: String, feeds: [Feed]) -> [Article] {
        let nonQueryFeeds = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [] : [$1]) }
        let articles = nonQueryFeeds.reduce(Array<Article>()) { $0 + $1.articlesArray }
        let script = "var query = \(query)\n" +
            "var script = function(articles) {\n" +
            "  var ret = [];\n" +
            "  for (var i = 0; i < articles.length; i++) {\n" +
            "    var article = articles[i];\n" +
            "    if (query(article)) { ret.push(article) }\n" +
            "  }\n" +
            "  return ret\n" +
        "}"
        return self.scriptService.runScript(script, arguments: [articles])
    }

    func newFeed() -> Future<Feed> {
        let promise = Promise<Feed>()
        self.dataService.createFeed(promise.resolve)
        return promise.future
    }

    func saveFeed(feed: Feed) -> Future<Void> {
        self._feeds = nil // Do I need to do this?
        return self.dataService.saveFeed(feed)
    }

    func deleteFeed(feed: Feed) -> Future<(Feed, Int)> {
        self._feeds = self._feeds?.filter { $0 != feed }

        return self.dataService.deleteFeed(feed).map {
            return self.feeds().map {
                return (feed, $0.count)
            }
        }
    }

    func saveArticle(article: Article) -> Future<Void> {
        return self.dataService.saveArticle(article)
    }

    func deleteArticle(article: Article) -> Future<Void> {
        return self.dataService.deleteArticle(article)
    }
}

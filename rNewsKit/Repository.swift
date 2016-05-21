import CBGPromise
import Result

enum RepositoryError: ErrorType {
    case Unknown
}

protocol Repository {
    associatedtype Data

    func get() -> Future<Result<[Data], RepositoryError>>
    func create() -> Future<Result<Data, RepositoryError>>
    func save(data: Data) -> Future<Result<Void, RepositoryError>>
    func delete(data: Data) -> Future<Result<Void, RepositoryError>>
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
    func get() -> Future<Result<[Feed], RepositoryError>> {
        let promise = Promise<Result<[Feed], RepositoryError>>()
        promise.resolve(Result(error: .Unknown))
        return promise.future
//        if let feeds = self._feeds {
//            let promise = Promise<Result<[Feed], RepositoryError>>()
//            promise.resolve(Result(value: feeds))
//            return promise.future
//        }
//        return self.dataService.allFeeds().map { feedArray -> Result<[Feed], RepositoryError> in
//            let unsorted = Array(feedArray)
//            let feeds = unsorted.sort { return $0.displayTitle < $1.displayTitle }
//
//            let nonQueryFeeds = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [] : [$1]) }
//            let queryFeeds    = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [$1] : []) }
//            for feed in queryFeeds {
//                let articles = self.articlesMatchingQuery(feed.query!, feeds: nonQueryFeeds)
//                articles.forEach { feed.addArticle($0) }
//            }
//            return Result(value: feeds)
//        }
    }

//    func articlesMatchingQuery(query: String, feeds: [Feed]) -> [Article] {
//        let nonQueryFeeds = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [] : [$1]) }
//        let articles = nonQueryFeeds.reduce(Array<Article>()) { $0 + $1.articlesArray }
//        let script = "var query = \(query)\n" +
//            "var script = function(articles) {\n" +
//            "  var ret = [];\n" +
//            "  for (var i = 0; i < articles.length; i++) {\n" +
//            "    var article = articles[i];\n" +
//            "    if (query(article)) { ret.push(article) }\n" +
//            "  }\n" +
//            "  return ret\n" +
//        "}"
//        return self.scriptService.runScript(script, arguments: [articles])
//    }

    func create() -> Future<Result<Feed, RepositoryError>> {
        let promise = Promise<Result<Feed, RepositoryError>>()
        self.dataService.createFeed {
            promise.resolve(Result(value: $0))
        }
        return promise.future
    }

    func save(data: Feed) -> Future<Result<Void, RepositoryError>> {
        self._feeds = nil
        return self.dataService.saveFeed(data).map { _ -> Result<Void, RepositoryError> in
            return Result(error: .Unknown)
        }
    }

    func delete(data: Feed) -> Future<Result<Void, RepositoryError>> {
        self._feeds = self._feeds?.filter { $0 != data }

        return self.dataService.deleteFeed(data).map { _ -> Result<Void, RepositoryError> in
            return Result(error: .Unknown)
        }
    }

//    func deleteFeed(feed: Feed) -> Future<(Feed, Int)> {
//        self._feeds = self._feeds?.filter { $0 != feed }
//
//        return self.dataService.deleteFeed(feed).map {
//            return self.feeds().map {
//                return (feed, $0.count)
//            }
//        }
//    }
//
//    func saveArticle(article: Article) -> Future<Void> {
//        return self.dataService.saveArticle(article)
//    }
//
//    func deleteArticle(article: Article) -> Future<Void> {
//        return self.dataService.deleteArticle(article)
//    }
}

import Foundation
import Ra
import CoreData
import JavaScriptCore
import Muon
import CBGPromise
import Result
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
    import UIKit
    import Reachability
#elseif os(OSX)
    import Cocoa
#endif

class DefaultDatabaseUseCase: DatabaseUseCase {
    private let mainQueue: NSOperationQueue

    private let reachable: Reachable?

    private let dataServiceFactory: DataServiceFactoryType
    private let updateService: UpdateServiceType
    private let databaseMigrator: DatabaseMigratorType
    let scriptService: ScriptService


    private var dataService: DataService {
        return self.dataServiceFactory.currentDataService
    }

    init(mainQueue: NSOperationQueue,
        reachable: Reachable?,
        dataServiceFactory: DataServiceFactoryType,
        updateService: UpdateServiceType,
        databaseMigrator: DatabaseMigratorType,
        scriptService: ScriptService) {
            self.mainQueue = mainQueue
            self.reachable = reachable
            self.dataServiceFactory = dataServiceFactory
            self.updateService = updateService
            self.databaseMigrator = databaseMigrator
            self.scriptService = scriptService
    }

    func databaseUpdateAvailable() -> Bool {
        return self.dataServiceFactory.currentDataService is CoreDataService
    }

    func performDatabaseUpdates(progress: Double -> Void, callback: Void -> Void) {
        guard self.databaseUpdateAvailable() else { return callback() }
        let currentDataService = self.dataServiceFactory.currentDataService
        if currentDataService is CoreDataService {
            let replacementDataService = self.dataServiceFactory.newDataService()
            self.databaseMigrator.migrate(currentDataService, to: replacementDataService, progress: { value in
                let reportedProgressValue = value / 2.0
                progress(reportedProgressValue)
            }) {
                self.dataServiceFactory.currentDataService = replacementDataService

                self.databaseMigrator.deleteEverything(currentDataService, progress: { value in
                    progress(0.5 + (value / 2.0))
                    }) {
                        callback()
                }
            }
        }
    }

    //MARK: - DataRetriever

    func allTags() -> Future<Result<[String], RNewsError>> {
        return self.feeds().map {
            return $0.map { feeds in
                let setOfTags = feeds.reduce(Set<String>()) {set, feed in set.union(Set(feed.tags)) }
                return Array(setOfTags).sort { return $0.lowercaseString < $1.lowercaseString }
            }
        }
    }

    func feeds() -> Future<Result<[Feed], RNewsError>> {
        return self.allFeeds()
    }

    func articlesOfFeed(feed: Feed, matchingSearchQuery query: String) -> DataStoreBackedArray<Article> {
            guard !feed.isQueryFeed else { return DataStoreBackedArray() }
            let articles = feed.articlesArray
            let predicates = [
                NSPredicate(format: "title CONTAINS[cd] %@", query),
                NSPredicate(format: "summary CONTAINS[cd] %@", query),
                NSPredicate(format: "content CONTAINS[cd] %@", query),
            ]
            let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            return articles.filterWithPredicate(compoundPredicate)
    }

    func articlesMatchingQuery(query: String) -> Future<Result<[Article], RNewsError>> {
        return self.feeds().map { result in
            return result.map { feeds in
                return self.articlesMatchingQuery(query, feeds: feeds)
            }
        }
    }

    // MARK: Private (DataRetriever)

    private func allFeeds() -> Future<Result<[Feed], RNewsError>> {
        return self.dataService.allFeeds().map { result in
            return result.map { unsorted_feeds in
                let unsorted = Array(unsorted_feeds)
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
    }

    private func articlesMatchingQuery(query: String, feeds: [Feed]) -> [Article] {
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

    // MARK: DataWriter

    private let subscribers = NSHashTable.weakObjectsHashTable()
    private var allSubscribers: [DataSubscriber] {
        return self.subscribers.allObjects.flatMap { $0 as? DataSubscriber }
    }

    func addSubscriber(subscriber: DataSubscriber) {
        subscribers.addObject(subscriber)
    }

    func newFeed(callback: (Feed) -> (Void)) {
        self.dataService.createFeed(callback)
    }

    func saveFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        return self.dataService.saveFeed(feed)
    }

    func deleteFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        return self.dataService.deleteFeed(feed).map { result -> Result<Void, RNewsError> in
            switch result {
            case .Success:
                self.feeds().then { feedsResult in
                    feedsResult.map { (feeds: [Feed]) -> Void in
                        for subscriber in self.allSubscribers {
                            subscriber.deletedFeed(feed, feedsLeft: feeds.count)
                        }
                    }
                }
                return .Success()
            case let .Failure(error):
                return .Failure(error)
            }
        }
    }

    func markFeedAsRead(feed: Feed) -> Future<Result<Int, RNewsError>> {
        let articles = feed.articlesArray.filterWithPredicate(NSPredicate(format: "read != 1"))
        return self.privateMarkArticles(Array(articles), asRead: true).map {
            return $0.map { articlesCount in
                feed.resetUnreadArticles()
                return articlesCount
            }
        }
    }

    func saveArticle(article: Article) -> Future<Result<Void, RNewsError>> {
        return self.dataService.batchSave([], articles: [article], enclosures: [])
    }

    func deleteArticle(article: Article) -> Future<Result<Void, RNewsError>> {
        return self.dataService.deleteArticle(article).then { _ in
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    subscriber.deletedArticle(article)
                }
            }
        }
    }

    func markArticle(article: Article, asRead: Bool) -> Future<Result<Void, RNewsError>> {
        return self.privateMarkArticles([article], asRead: asRead).map { result -> Result<Void, RNewsError> in
            switch result {
            case .Success(_):
                return .Success()
            case let .Failure(error):
                return .Failure(error)
            }
        }
    }

    private var updatingFeedsCallbacks = Array<([Feed], [NSError]) -> (Void)>()
    func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        self.updatingFeedsCallbacks.append(callback)
        guard self.updatingFeedsCallbacks.count == 1 else { return }

        self.feeds().map { result in
            return result.map { feeds in
                guard feeds.isEmpty == false && self.reachable?.hasNetworkConnectivity == true else {
                    self.updatingFeedsCallbacks.forEach { $0([], []) }
                    self.updatingFeedsCallbacks = []
                    return
                }

                self.privateUpdateFeeds(feeds) {updatedFeeds, errors in
                    for updateCallback in self.updatingFeedsCallbacks {
                        self.mainQueue.addOperationWithBlock { updateCallback(updatedFeeds, errors) }
                    }
                    for object in self.subscribers.allObjects {
                        if let subscriber = object as? DataSubscriber {
                            self.mainQueue.addOperationWithBlock {
                                subscriber.didUpdateFeeds(updatedFeeds)
                            }
                        }
                    }
                    self.updatingFeedsCallbacks = []
                }
            }
        }
    }

    func updateFeed(feed: Feed, callback: (Feed?, NSError?) -> (Void)) {
        guard self.reachable?.hasNetworkConnectivity == true else {
            callback(feed, nil)
            return
        }
        self.privateUpdateFeeds([feed]) {feeds, errors in
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    self.mainQueue.addOperationWithBlock {
                        subscriber.didUpdateFeeds(feeds)
                    }
                }
                self.mainQueue.addOperationWithBlock { callback(feeds.first, errors.first) }
            }
        }
    }

    //MARK: Private (DataWriter)

    private func privateMarkArticles(articles: [Article], asRead read: Bool) -> Future<Result<Int, RNewsError>> {
        guard articles.count > 0 else {
            let promise = Promise<Result<Int, RNewsError>>()
            promise.resolve(.Success(0))
            return promise.future
        }

        let amountToChange = articles.filter({ $0.read == !read }).count
        for article in articles {
            article.read = read
        }
        return self.dataService.batchSave([], articles: articles, enclosures: []).map { result in
            return result.map {
                for object in self.subscribers.allObjects {
                    if let subscriber = object as? DataSubscriber {
                        subscriber.markedArticles(articles, asRead: read)
                    }
                }
                return amountToChange
            }
        }
    }

    private func privateUpdateFeeds(feeds: [Feed], callback: ([Feed], [NSError]) -> (Void)) {
        var feedsLeft = feeds.count
        guard feedsLeft != 0 else {
            callback([], [])
            return
        }

        for object in self.subscribers.allObjects {
            if let subscriber = object as? DataSubscriber {
                subscriber.willUpdateFeeds()
            }
        }

        var updatedFeeds: [Feed] = []
        var errors: [NSError] = []

        var totalProgress = feedsLeft
        var currentProgress = 0

        for feed in feeds {
            guard let _ = feed.url where feed.remainingWait == 0 else {
                feed.remainingWait -= 1
                self.dataService.saveFeed(feed)
                feedsLeft -= 1
                totalProgress -= 1
                if feedsLeft == 0 {
                    callback(updatedFeeds, errors)
                }
                continue
            }
            self.updateService.updateFeed(feed) { feed, error in
                if let error = error {
                    errors.append(error)
                }
                updatedFeeds.append(feed)

                currentProgress += 1
                self.mainQueue.addOperationWithBlock {
                    for object in self.subscribers.allObjects {
                        if let subscriber = object as? DataSubscriber {
                            subscriber.didUpdateFeedsProgress(currentProgress, total: totalProgress)
                        }
                    }
                }

                feedsLeft -= 1
                if feedsLeft == 0 {
                    self.allFeeds().then { result in
                        switch result {
                        case let .Success(feeds):
                            callback(feeds, errors)
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
}

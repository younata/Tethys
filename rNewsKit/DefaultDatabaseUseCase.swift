import Foundation
import Ra
import CoreData
import JavaScriptCore
import Muon
import CBGPromise
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

    func allTags(callback: [String] -> Void) {
        self.feeds { feeds in
            let setOfTags = feeds.reduce(Set<String>()) {set, feed in set.union(Set(feed.tags)) }
            let tags = Array(setOfTags).sort { return $0.lowercaseString < $1.lowercaseString }
            callback(tags)
        }
    }

    func feeds(callback: [Feed] -> Void) {
        self.allFeeds(callback)
    }

    func articlesOfFeeds(feeds: [Feed], matchingSearchQuery query: String) -> DataStoreBackedArray<Article> {
            let feeds = feeds.filter { !$0.isQueryFeed }
            guard !feeds.isEmpty else {
                return DataStoreBackedArray()
            }
            var articles = feeds[0].articlesArray
            for feed in feeds[1..<feeds.count] {
                articles = articles.combine(feed.articlesArray)
            }
            let predicates = [
                NSPredicate(format: "title CONTAINS[cd] %@", query),
                NSPredicate(format: "summary CONTAINS[cd] %@", query),
                NSPredicate(format: "content CONTAINS[cd] %@", query),
            ]
            let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            return articles.filterWithPredicate(compoundPredicate)
    }

    func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        self.feeds { feeds in
            let queriedArticles = self.articlesMatchingQuery(query, feeds: feeds)
            callback(queriedArticles)
        }
    }

    // MARK: Private (DataRetriever)

    private func allFeeds(callback: [Feed] -> Void) {
        self.dataService.allFeeds().then {
            let unsorted = Array($0)
            let feeds = unsorted.sort { return $0.displayTitle < $1.displayTitle }

            let nonQueryFeeds = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [] : [$1]) }
            let queryFeeds    = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [$1] : []) }
            for feed in queryFeeds {
                let articles = self.articlesMatchingQuery(feed.query!, feeds: nonQueryFeeds)
                articles.forEach { feed.addArticle($0) }
            }
            callback(feeds)
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

    func addSubscriber(subscriber: DataSubscriber) {
        subscribers.addObject(subscriber)
    }

    func newFeed(callback: (Feed) -> (Void)) {
        self.dataService.createFeed(callback)
    }

    func saveFeed(feed: Feed) -> Future<Void> {
        return self.dataService.saveFeed(feed)
    }

    func deleteFeed(feed: Feed) -> Future<Void> {
        return self.dataService.deleteFeed(feed).then {
            self.feeds {
                for object in self.subscribers.allObjects {
                    if let subscriber = object as? DataSubscriber {
                        subscriber.deletedFeed(feed, feedsLeft: $0.count)
                    }
                }
            }
        }
    }

    func markFeedAsRead(feed: Feed) -> Future<Int> {
        let articles = feed.articlesArray.filterWithPredicate(NSPredicate(format: "read != 1"))
        return self.privateMarkArticles(Array(articles), asRead: true).map { (articlesCount: Int) -> Int in
            feed.resetUnreadArticles()
            return articlesCount
        }
    }

    func saveArticle(article: Article) -> Future<Void> {
        return self.dataService.saveArticle(article)
    }

    func deleteArticle(article: Article) -> Future<Void> {
        return self.dataService.deleteArticle(article).then {
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    subscriber.deletedArticle(article)
                }
            }
        }
    }

    func markArticle(article: Article, asRead: Bool) -> Future<Void> {
        return self.privateMarkArticles([article], asRead: asRead).map { _ -> Void in
            return
        }
    }

    private var updatingFeedsCallbacks = Array<([Feed], [NSError]) -> (Void)>()
    func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        self.updatingFeedsCallbacks.append(callback)
        guard self.updatingFeedsCallbacks.count == 1 else { return }

        self.feeds {feeds in
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

    private func privateMarkArticles(articles: [Article], asRead read: Bool) -> Future<Int> {
        guard articles.count > 0 else {
            let promise = Promise<Int>()
            promise.resolve(0)
            return promise.future
        }

        let amountToChange = articles.filter({ $0.read == !read }).count
        for article in articles {
            article.read = read
        }
        return self.dataService.batchSave([], articles: articles, enclosures: []).map { (_: Void) -> Int in
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    subscriber.markedArticles(articles, asRead: read)
                }
            }
            return amountToChange
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
                    self.allFeeds {
                        callback($0, errors)
                    }
                }
            }
        }
    }
}

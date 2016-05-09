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

public protocol FeedRepository {
    func databaseUpdateAvailable() -> Bool
    func performDatabaseUpdates(progress: Double -> Void, callback: Void -> Void)

    func allTags(callback: [String] -> Void)
    func feeds(callback: [Feed] -> Void)
    func feedsMatchingTag(tag: String?, callback: [Feed] -> Void)
    func articlesOfFeeds(feeds: [Feed], matchingSearchQuery: String, callback: DataStoreBackedArray<Article> -> Void)
    func articlesMatchingQuery(query: String, callback: [Article] -> Void)

    func addSubscriber(subscriber: DataSubscriber)

    func newFeed(callback: Feed -> Void)
    func saveFeed(feed: Feed)
    func deleteFeed(feed: Feed)
    func markFeedAsRead(feed: Feed) -> Future<Int>

    func saveArticle(article: Article)
    func deleteArticle(article: Article)
    func markArticle(article: Article, asRead: Bool)

    func updateFeeds(callback: ([Feed], [NSError]) -> Void)

    func updateFeed(feed: Feed, callback: (Feed?, NSError?) -> Void)
}

public protocol DataSubscriber: NSObjectProtocol {
    func markedArticles(articles: [Article], asRead read: Bool)

    func deletedArticle(article: Article)

    func deletedFeed(feed: Feed, feedsLeft: Int)

    func willUpdateFeeds()
    func didUpdateFeedsProgress(finished: Int, total: Int)
    func didUpdateFeeds(feeds: [Feed])
}

protocol Reachable {
    var hasNetworkConnectivity: Bool { get }
}

#if os(iOS)
    extension Reachability: Reachable {
        var hasNetworkConnectivity: Bool {
            return self.currentReachabilityStatus != .NotReachable
        }
    }
#endif

class DataRepository: FeedRepository {
    private let mainQueue: NSOperationQueue

    private let reachable: Reachable?

    private let dataServiceFactory: DataServiceFactoryType
    private let updateService: UpdateServiceType
    private let databaseMigrator: DatabaseMigratorType


    private var dataService: DataService {
        return self.dataServiceFactory.currentDataService
    }

    init(mainQueue: NSOperationQueue,
        reachable: Reachable?,
        dataServiceFactory: DataServiceFactoryType,
        updateService: UpdateServiceType,
        databaseMigrator: DatabaseMigratorType) {
            self.mainQueue = mainQueue
            self.reachable = reachable
            self.dataServiceFactory = dataServiceFactory
            self.updateService = updateService
            self.databaseMigrator = databaseMigrator
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
        self.dataService.feedsMatchingPredicate(NSPredicate(format: "tags.@count > 0")) { feedsWithTags in
            let setOfTags = feedsWithTags.reduce(Set<String>()) {set, feed in set.union(Set(feed.tags)) }
            let tags = Array(setOfTags).sort { return $0.lowercaseString < $1.lowercaseString }
            callback(tags)
        }
    }

    func feeds(callback: [Feed] -> Void) {
        self.dataService.allFeeds {
            callback(Array($0))
        }
    }

    func feedsMatchingTag(tag: String?, callback: [Feed] -> Void) {
        if let theTag = tag where !theTag.isEmpty {
            self.feeds {
                let feeds = $0.filter { feed in
                    let tags = feed.tags
                    for t in tags {
                        if t.rangeOfString(theTag) != nil {
                            return true
                        }
                    }
                    return false
                }
                callback(feeds)
            }
        } else {
            self.feeds(callback)
        }
    }


    func articlesOfFeeds(feeds: [Feed],
        matchingSearchQuery query: String,
        callback: DataStoreBackedArray<Article> -> Void) {
            let feeds = feeds.filter { !$0.isQueryFeed }
            guard !feeds.isEmpty else {
                self.mainQueue.addOperationWithBlock { callback(DataStoreBackedArray()) }
                return
            }
            var articles = feeds[0].articlesArray
            for feed in feeds[1..<feeds.count] {
                articles = articles.combine(feed.articlesArray)
            }
            let predicates = [
                NSPredicate(format: "title CONTAINS[cd] %@", query),
                NSPredicate(format: "summary CONTAINS[cd] %@", query),
//                NSPredicate(format: "author CONTAINS[cd] %@", query),
                NSPredicate(format: "content CONTAINS[cd] %@", query),
            ]
            let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            let returnValue = articles.filterWithPredicate(compoundPredicate)
            self.mainQueue.addOperationWithBlock { callback(returnValue) }
    }

    func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        self.allFeeds { feeds in
            let queriedArticles = self.privateArticlesMatchingQuery(query, feeds: feeds)
            self.mainQueue.addOperationWithBlock { callback(queriedArticles) }
        }
    }

    // MARK: Private (DataRetriever)

    private func allFeeds(callback: ([Feed] -> (Void))) {
        self.feeds {unsorted in
            let feeds = unsorted.sort { return $0.displayTitle < $1.displayTitle }

            let nonQueryFeeds = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [] : [$1]) }
            let queryFeeds    = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [$1] : []) }
            for feed in queryFeeds {
                let articles = self.privateArticlesMatchingQuery(feed.query!, feeds: nonQueryFeeds)
                articles.forEach { feed.addArticle($0) }
            }
            callback(feeds)
        }
    }

    private func privateArticlesMatchingQuery(query: String, feeds: [Feed]) -> [Article] {
        let nonQueryFeeds = feeds.reduce(Array<Feed>()) { $0 + ($1.isQueryFeed ? [] : [$1]) }
        let articles = nonQueryFeeds.reduce(Array<Article>()) { $0 + $1.articlesArray }
        let context = JSContext()
        context.exceptionHandler = { _, exception in
            print("JS Error: \(exception)")
        }
        let script = "var query = \(query)\n" +
            "var include = function(articles) {\n" +
            "  var ret = [];\n" +
            "  for (var i = 0; i < articles.length; i++) {\n" +
            "    var article = articles[i];\n" +
            "    if (query(article)) { ret.push(article) }\n" +
            "  }\n" +
            "  return ret\n" +
        "}"
        context.evaluateScript(script)
        let include = context.objectForKeyedSubscript("include")
        let res = include.callWithArguments([articles]).toArray()
        return res as? [Article] ?? []
    }

    // MARK: DataWriter

    private let subscribers = NSHashTable.weakObjectsHashTable()

    func addSubscriber(subscriber: DataSubscriber) {
        subscribers.addObject(subscriber)
    }

    func newFeed(callback: (Feed) -> (Void)) {
        self.dataService.createFeed(callback)
    }

    func saveFeed(feed: Feed) {
        self.dataService.saveFeed(feed) {}
    }

    func deleteFeed(feed: Feed) {
        self.dataService.deleteFeed(feed) {
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

    func saveArticle(article: Article) {
        self.dataService.saveArticle(article) {}
    }

    func deleteArticle(article: Article) {
        self.dataService.deleteArticle(article) {
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    subscriber.deletedArticle(article)
                }
            }
        }
    }

    func markArticle(article: Article, asRead: Bool) {
        self.privateMarkArticles([article], asRead: asRead)
    }

    private var updatingFeedsCallbacks = Array<([Feed], [NSError]) -> (Void)>()
    func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        self.updatingFeedsCallbacks.append(callback)
        guard self.updatingFeedsCallbacks.count == 1 else { return }

        self.allFeeds {feeds in
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
        let promise = Promise<Int>()
        guard articles.count > 0 else {
            promise.resolve(0)
            return promise.future
        }

        let amountToChange = articles.filter({ $0.read == !read }).count
        for article in articles {
            article.read = read
        }
        self.dataService.batchSave([], articles: articles, enclosures: []) {
            promise.resolve(amountToChange)
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    subscriber.markedArticles(articles, asRead: read)
                }
            }
        }
        return promise.future
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
                self.dataService.saveFeed(feed) {}
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

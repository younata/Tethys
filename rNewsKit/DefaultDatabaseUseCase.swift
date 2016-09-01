import Foundation
import Ra
import CoreData
import JavaScriptCore
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
    private let updateUseCase: UpdateUseCase
    private let databaseMigrator: DatabaseMigratorType
    private let accountRepository: InternalAccountRepository

    private var dataService: DataService {
        return self.dataServiceFactory.currentDataService
    }

    init(mainQueue: NSOperationQueue,
        reachable: Reachable?,
        dataServiceFactory: DataServiceFactoryType,
        updateUseCase: UpdateUseCase,
        databaseMigrator: DatabaseMigratorType,
        accountRepository: InternalAccountRepository) {
            self.mainQueue = mainQueue
            self.reachable = reachable
            self.dataServiceFactory = dataServiceFactory
            self.updateUseCase = updateUseCase
            self.databaseMigrator = databaseMigrator
            self.accountRepository = accountRepository
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
            let articles = feed.articlesArray
            let predicates = [
                NSPredicate(format: "title CONTAINS[c] %@", query),
                NSPredicate(format: "summary CONTAINS[c] %@", query),
                NSPredicate(format: "content CONTAINS[c] %@", query),
            ]
            let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            return articles.filterWithPredicate(compoundPredicate)
    }

    // MARK: Private (DataRetriever)

    private func allFeeds() -> Future<Result<[Feed], RNewsError>> {
        return self.dataService.allFeeds().map { result in
            return result.map { unsorted_feeds in
                let unsorted = Array(unsorted_feeds)
                return unsorted.sort { return $0.displayTitle < $1.displayTitle }
            }
        }
    }

    // MARK: DataWriter

    private let subscribers = NSHashTable.weakObjectsHashTable()
    private var allSubscribers: [DataSubscriber] {
        return self.subscribers.allObjects.flatMap { $0 as? DataSubscriber }
    }

    func addSubscriber(subscriber: DataSubscriber) {
        subscribers.addObject(subscriber)
    }

    func newFeed(callback: (Feed) -> (Void)) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        self.dataService.createFeed {
            callback($0)
            if !$0.url.absoluteString.isEmpty, let sinopeRepository = self.accountRepository.backendRepository() {
                sinopeRepository.subscribe([$0.url]).then { res in
                    switch res {
                    case .Success(_):
                        promise.resolve(.Success())
                    case let .Failure(error):
                        promise.resolve(.Failure(.Backend(error)))
                    }
                }
            } else {
                promise.resolve(.Success())
            }
        }
        return promise.future
    }

    func saveFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        return self.dataService.saveFeed(feed)
    }

    func deleteFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        return self.dataService.deleteFeed(feed).map { result -> Future<Result<Void, RNewsError>> in
            switch result {
            case .Success:
                let future: Future<Result<[NSURL], RNewsError>>
                if let sinopeRepository = self.accountRepository.backendRepository() {
                    future = sinopeRepository.unsubscribe([feed.url]).map { res in
                        return res.mapError { return RNewsError.Backend($0) }
                    }
                } else {
                    let promise = Promise<Result<[NSURL], RNewsError>>()
                    promise.resolve(.Success([]))
                    future = promise.future
                }
                return future.map { _ in
                    return self.feeds().map { feedsResult -> Result<Void, RNewsError> in
                        _ = feedsResult.map { (feeds: [Feed]) -> Void in
                            self.mainQueue.addOperationWithBlock {
                                for subscriber in self.allSubscribers {
                                    subscriber.deletedFeed(feed, feedsLeft: feeds.count)
                                }
                            }
                        }
                        return .Success()
                    }
                }
            case let .Failure(error):
                let promise = Promise<Result<Void, RNewsError>>()
                promise.resolve(.Failure(error))
                return promise.future
            }
        }
    }

    func markFeedAsRead(feed: Feed) -> Future<Result<Int, RNewsError>> {
        let articles = feed.articlesArray.filterWithPredicate(NSPredicate(format: "read != 1"))
        return self.privateMarkArticles(Array(articles), asRead: true).map {
            return $0.map { articlesCount in
                return articlesCount
            }
        }
    }

    func saveArticle(article: Article) -> Future<Result<Void, RNewsError>> {
        return self.dataService.batchSave([], articles: [article])
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
        return self.dataService.batchSave([], articles: articles).map { result in
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
        self.updateUseCase.updateFeeds(feeds, subscribers: self.allSubscribers).then { res in
            self.allFeeds().then { result in
                switch result {
                case let .Success(feeds):
                    callback(feeds, [])
                case .Failure(_):
                    callback([], [NSError(domain: "RNewsError", code: 0, userInfo: [:])])
                }
            }
        }
    }
}

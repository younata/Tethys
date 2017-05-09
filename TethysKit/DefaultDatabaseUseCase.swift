import Foundation
import Ra
import CBGPromise
import Result
import Sinope
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
    import UIKit
    import Reachability
#elseif os(OSX)
    import Cocoa
#endif

class DefaultDatabaseUseCase: DatabaseUseCase {
    private let mainQueue: OperationQueue

    private let reachable: Reachable?

    private let dataServiceFactory: DataServiceFactoryType
    private let updateUseCase: UpdateUseCase
    private let databaseMigrator: DatabaseMigratorType
    private let accountRepository: InternalAccountRepository
    private let syncManager: SyncManager

    private var dataService: DataService {
        return self.dataServiceFactory.currentDataService
    }

    // swiftlint:disable function_parameter_count
    init(mainQueue: OperationQueue,
         reachable: Reachable?,
         dataServiceFactory: DataServiceFactoryType,
         updateUseCase: UpdateUseCase,
         databaseMigrator: DatabaseMigratorType,
         accountRepository: InternalAccountRepository,
         syncManager: SyncManager) {
        self.mainQueue = mainQueue
        self.reachable = reachable
        self.dataServiceFactory = dataServiceFactory
        self.updateUseCase = updateUseCase
        self.databaseMigrator = databaseMigrator
        self.accountRepository = accountRepository
        self.syncManager = syncManager
    }
    // swiftlint:enable function_parameter_count

    func databaseUpdateAvailable() -> Bool {
        return false
    }

    func performDatabaseUpdates(_ progress: @escaping (Double) -> Void, callback: @escaping (Void) -> Void) {
        guard self.databaseUpdateAvailable() else { return callback() }
    }

    // MARK: - DataRetriever

    func allTags() -> Future<Result<[String], TethysError>> {
        return self.feeds().map {
            return $0.map { feeds in
                let setOfTags = feeds.reduce(Set<String>()) {set, feed in set.union(Set(feed.tags)) }
                let arrayOfTags: [String] = Array(setOfTags)
                return arrayOfTags.sorted()
            }
        }
    }

    func feeds() -> Future<Result<[Feed], TethysError>> {
        return self.allFeeds()
    }

    func articles(feed: Feed, matchingSearchQuery query: String) -> DataStoreBackedArray<Article> {
            let articles = feed.articlesArray
            let predicates = [
                NSPredicate(format: "title CONTAINS[c] %@", query),
                NSPredicate(format: "summary CONTAINS[c] %@", query),
                NSPredicate(format: "content CONTAINS[c] %@", query)
            ]
            let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            return articles.filterWithPredicate(compoundPredicate)
    }

    func findRelatedArticles(to article: Article) -> Future<Result<[Article], TethysError>> {
        return self.dataService.findRelatedArticles(to: article)
    }

    // MARK: Private (DataRetriever)

    private func allFeeds() -> Future<Result<[Feed], TethysError>> {
        return self.dataService.allFeeds().map { result in
            return result.map { unsorted_feeds in
                let unsorted = Array(unsorted_feeds)
                return unsorted.sorted { return $0.displayTitle < $1.displayTitle }
            }
        }
    }

    // MARK: DataWriter

    private let subscribers = NSHashTable<AnyObject>.weakObjects()
    private var allSubscribers: [DataSubscriber] {
        return self.subscribers.allObjects.flatMap { $0 as? DataSubscriber }
    }

    func addSubscriber(_ subscriber: DataSubscriber) {
        subscribers.add(subscriber)
    }

    func newFeed(url: URL, callback: @escaping (Feed) -> (Void)) -> Future<Result<Void, TethysError>> {
        let promise = Promise<Result<Void, TethysError>>()
        _ = self.dataService.createFeed(url: url) {
            callback($0)
            if !($0.url.absoluteString).isEmpty,
                let sinopeRepository = self.accountRepository.backendRepository() {
                    _ = sinopeRepository.subscribe([$0.url]).then { res in
                        switch res {
                        case .success(_):
                            promise.resolve(.success())
                        case let .failure(error):
                            promise.resolve(.failure(.backend(error)))
                        }
                    }
            } else {
                promise.resolve(.success())
            }
        }
        return promise.future
    }

    func saveFeed(_ feed: Feed) -> Future<Result<Void, TethysError>> {
        return self.dataService.saveFeed(feed)
    }

    func deleteFeed(_ feed: Feed) -> Future<Result<Void, TethysError>> {
        return self.dataService.deleteFeed(feed).map { result -> Future<Result<Void, TethysError>> in
            switch result {
            case .success:
                let future: Future<Result<[URL], TethysError>>
                if let sinopeRepository = self.accountRepository.backendRepository() {
                    let urls = [feed.url]
                    future = sinopeRepository.unsubscribe(urls).map { res in
                        return res.mapError { return TethysError.backend($0) }
                    }
                } else {
                    let promise = Promise<Result<[URL], TethysError>>()
                    promise.resolve(.success([]))
                    future = promise.future
                }
                return future.map { _ in
                    return self.feeds().map { feedsResult -> Result<Void, TethysError> in
                        _ = feedsResult.map { (feeds: [Feed]) -> Void in
                            self.mainQueue.addOperation {
                                for subscriber in self.allSubscribers {
                                    subscriber.deletedFeed(feed, feedsLeft: feeds.count)
                                }
                            }
                        }
                        return .success()
                    }
                }
            case let .failure(error):
                let promise = Promise<Result<Void, TethysError>>()
                promise.resolve(.failure(error))
                return promise.future
            }
        }
    }

    func markFeedAsRead(_ feed: Feed) -> Future<Result<Int, TethysError>> {
        let articles = feed.articlesArray.filterWithPredicate(NSPredicate(format: "read != 1"))
        return self.privateMarkArticles(Array(articles), asRead: true).map {
            return $0.map { articlesCount in
                return articlesCount
            }
        }
    }

    func deleteArticle(_ article: Article) -> Future<Result<Void, TethysError>> {
        return self.dataService.deleteArticle(article).then { _ in
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    subscriber.deletedArticle(article)
                }
            }
        }
    }

    func markArticle(_ article: Article, asRead: Bool) -> Future<Result<Void, TethysError>> {
        return self.privateMarkArticles([article], asRead: asRead).map { result -> Result<Void, TethysError> in
            switch result {
            case .success(_):
                return .success()
            case let .failure(error):
                return .failure(error)
            }
        }
    }

    private var updatingFeedsCallbacks = [([Feed], [NSError]) -> (Void)]()
    func updateFeeds(_ callback: @escaping ([Feed], [NSError]) -> (Void)) {
        self.updatingFeedsCallbacks.append(callback)
        guard self.updatingFeedsCallbacks.count == 1 else { return }

        _ = self.feeds().map { result in
            return result.map { feeds in
                guard feeds.isEmpty == false && self.reachable?.hasNetworkConnectivity == true else {
                    self.updatingFeedsCallbacks.forEach { $0([], []) }
                    self.updatingFeedsCallbacks = []
                    for subscriber in self.allSubscribers {
                        self.mainQueue.addOperation {
                            subscriber.didUpdateFeeds([])
                        }
                    }
                    return
                }

                self.privateUpdateFeeds(feeds) {updatedFeeds, errors in
                    for updateCallback in self.updatingFeedsCallbacks {
                        self.mainQueue.addOperation { updateCallback(updatedFeeds, errors) }
                    }
                    for subscriber in self.allSubscribers {
                        self.mainQueue.addOperation {
                            subscriber.didUpdateFeeds(updatedFeeds)
                        }
                    }
                    self.updatingFeedsCallbacks = []
                }
            }
        }
    }

    func updateFeed(_ feed: Feed, callback: @escaping (Feed?, NSError?) -> (Void)) {
        guard self.reachable?.hasNetworkConnectivity == true else {
            callback(feed, nil)
            return
        }
        self.privateUpdateFeeds([feed]) {feeds, errors in
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    self.mainQueue.addOperation {
                        subscriber.didUpdateFeeds(feeds)
                    }
                }
                self.mainQueue.addOperation { callback(feeds.first, errors.first) }
            }
        }
    }

    // MARK: Private (DataWriter)

    private func privateMarkArticles(_ articles: [Article], asRead read: Bool) -> Future<Result<Int, TethysError>> {
        guard articles.count > 0 else {
            let promise = Promise<Result<Int, TethysError>>()
            promise.resolve(.success(0))
            return promise.future
        }

        let amountToChange = articles.filter({ $0.read == !read }).count
        for article in articles {
            article.read = read
        }
        self.syncManager.update(articles: articles)
        return self.dataService.batchSave([], articles: articles).map { result in
            return result.map {
                for subscriber in self.allSubscribers {
                    self.mainQueue.addOperation {
                        subscriber.markedArticles(articles, asRead: read)
                    }
                }
                return amountToChange
            }
        }
    }

    private func privateUpdateFeeds(_ feeds: [Feed], callback: @escaping ([Feed], [NSError]) -> (Void)) {
        _ = self.updateUseCase.updateFeeds(feeds, subscribers: self.allSubscribers).then { res in
            switch res {
            case .success(_):
                _ = self.allFeeds().then { result in
                    switch result {
                    case let .success(feeds):
                        callback(feeds, [])
                    case .failure(_):
                        callback([], [NSError(domain: "TethysError", code: 0, userInfo: [:])])
                    }
                }
            case let .failure(error):
                callback([], [NSError(domain: "TethysError",
                                      code: 0,
                                      userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])])
            }
        }
    }
}

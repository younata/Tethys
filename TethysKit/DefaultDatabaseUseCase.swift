import Foundation
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
    private let mainQueue: OperationQueue

    private let reachable: Reachable?

    private let dataServiceFactory: DataServiceFactoryType
    private let updateUseCase: UpdateUseCase

    private var dataService: DataService {
        return self.dataServiceFactory.currentDataService
    }

    init(mainQueue: OperationQueue,
         reachable: Reachable?,
         dataServiceFactory: DataServiceFactoryType,
         updateUseCase: UpdateUseCase) {
        self.mainQueue = mainQueue
        self.reachable = reachable
        self.dataServiceFactory = dataServiceFactory
        self.updateUseCase = updateUseCase
    }

    func databaseUpdateAvailable() -> Bool {
        return false
    }

    func performDatabaseUpdates(_ progress: @escaping (Double) -> Void, callback: @escaping () -> Void) {
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

    // MARK: Private (DataRetriever)

    private func allFeeds() -> Future<Result<[Feed], TethysError>> {
        return self.dataService.allFeeds().map { result -> Future<Result<[Feed], TethysError>> in
            switch result {
            case .success(let unsorted_feeds):
                return unsorted_feeds.array().map { unsorted -> Result<[Feed], TethysError> in
                    return .success(unsorted.sorted { return $0.displayTitle < $1.displayTitle })
                }
                //Array(unsorted_feeds)
            case .failure(let error):
                let promise = Promise<Result<[Feed], TethysError>>()
                promise.resolve(.failure(error))
                return promise.future
            }
        }
    }

    // MARK: DataWriter

    func newFeed(url: URL, callback: @escaping (Feed) -> Void) -> Future<Result<Void, TethysError>> {
        let promise = Promise<Result<Void, TethysError>>()
        _ = self.dataService.createFeed(url: url) {
            callback($0)
            promise.resolve(.success())
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
                return self.feeds().map { feedsResult -> Result<Void, TethysError> in
                    return .success()
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

    private var updatingFeedsCallbacks = [([Feed], [NSError]) -> Void]()
    func updateFeeds(_ callback: @escaping ([Feed], [NSError]) -> Void) {
        self.updatingFeedsCallbacks.append(callback)
        guard self.updatingFeedsCallbacks.count == 1 else { return }

        _ = self.feeds().map { result in
            return result.map { feeds in
                guard feeds.isEmpty == false && self.reachable?.hasNetworkConnectivity != false else {
                    self.updatingFeedsCallbacks.forEach { $0([], []) }
                    self.updatingFeedsCallbacks = []
                    return
                }

                self.privateUpdateFeeds(feeds) {updatedFeeds, errors in
                    for updateCallback in self.updatingFeedsCallbacks {
                        self.mainQueue.addOperation { updateCallback(updatedFeeds, errors) }
                    }
                    self.updatingFeedsCallbacks = []
                }
            }
        }
    }

    func updateFeed(_ feed: Feed, callback: @escaping (Feed?, NSError?) -> Void) {
        guard self.reachable?.hasNetworkConnectivity == true else {
            callback(feed, nil)
            return
        }
        self.privateUpdateFeeds([feed]) {feeds, errors in
            self.mainQueue.addOperation { callback(feeds.first, errors.first) }
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
        return self.dataService.batchSave([], articles: articles).map { result in
            return result.map {
                return amountToChange
            }
        }
    }

    private func privateUpdateFeeds(_ feeds: [Feed], callback: @escaping ([Feed], [NSError]) -> Void) {
        _ = self.updateUseCase.updateFeeds(feeds).then { res in
            switch res {
            case .success:
                _ = self.allFeeds().then { result in
                    switch result {
                    case let .success(feeds):
                        callback(feeds, [])
                    case .failure:
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

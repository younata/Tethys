import Foundation
import CBGPromise
import Result
@testable import rNewsKit

class FakeDatabaseUseCase: DatabaseUseCase {
    var _databaseUpdateAvailable = false
    func databaseUpdateAvailable() -> Bool {
        return self._databaseUpdateAvailable
    }

    var performDatabaseUpdatesProgress: ((Double) -> Void)?
    var perfomDatabaseUpdatesCallback: ((Void) -> Void)?
    func performDatabaseUpdates(_ progress: @escaping (Double) -> Void, callback: @escaping (Void) -> Void) {
        self.performDatabaseUpdatesProgress = progress
        self.perfomDatabaseUpdatesCallback = callback
    }

    var allTagsPromises: [Promise<Result<[String], RNewsError>>] = []
    func allTags() -> Future<Result<[String], RNewsError>> {
        let promise = Promise<Result<[String], RNewsError>>()
        self.allTagsPromises.append(promise)
        return promise.future
    }

    var feedsPromises: [Promise<Result<[Feed], RNewsError>>] = []
    func feeds() -> Future<Result<[Feed], RNewsError>> {
        let promise = Promise<Result<[Feed], RNewsError>>()
        self.feedsPromises.append(promise)
        return promise.future
    }

    var articlesOfFeedList = Array<Article>()
    func articles(feed: Feed, matchingSearchQuery: String) -> DataStoreBackedArray<Article> {
        return DataStoreBackedArray(articlesOfFeedList)
    }

    var articlesMatchingQueryPromises: [Promise<Result<[Article], RNewsError>>] = []
    func articlesMatchingQuery(_ query: String) -> Future<Result<[Article], RNewsError>> {
        let promise = Promise<Result<[Article], RNewsError>>()
        self.articlesMatchingQueryPromises.append(promise)
        return promise.future
    }

    // MARK: DataWriter

    let subscribers = NSHashTable<AnyObject>.weakObjects()
    var subscribersArray: [DataSubscriber] {
        return self.subscribers.allObjects.flatMap { $0 as? DataSubscriber }
    }
    func addSubscriber(_ subscriber: DataSubscriber) {
        self.subscribers.add(subscriber)
    }

    var newFeedCallback: (Feed) -> (Void) = {_ in }
    var didCreateFeed = false
    var newFeedPromises: [Promise<Result<Void, RNewsError>>] = []
    func newFeed(_ callback: @escaping (Feed) -> (Void)) -> Future<Result<Void, RNewsError>> {
        didCreateFeed = true
        self.newFeedCallback = callback
        let promise = Promise<Result<Void, RNewsError>>()
        newFeedPromises.append(promise)
        return promise.future
    }

    var lastSavedFeed: Feed? = nil
    var saveFeedPromises: [Promise<Result<Void, RNewsError>>] = []
    func saveFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>> {
        lastSavedFeed = feed
        let promise = Promise<Result<Void, RNewsError>>()
        saveFeedPromises.append(promise)
        return promise.future
    }

    var lastDeletedFeed: Feed? = nil
    var deletedFeeds = Array<Feed>()
    var deleteFeedPromises: [Promise<Result<Void, RNewsError>>] = []
    func deleteFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>> {
        deletedFeeds.append(feed)
        lastDeletedFeed = feed
        let promise = Promise<Result<Void, RNewsError>>()
        deleteFeedPromises.append(promise)
        return promise.future
    }

    var lastFeedMarkedRead: Feed? = nil
    var markedReadFeeds: [Feed] = []
    var lastFeedMarkedReadPromise: Promise<Result<Int, RNewsError>>? = nil
    func markFeedAsRead(_ feed: Feed) -> Future<Result<Int, RNewsError>> {
        lastFeedMarkedRead = feed
        markedReadFeeds.append(feed)
        self.lastFeedMarkedReadPromise = Promise<Result<Int, RNewsError>>()
        return self.lastFeedMarkedReadPromise!.future
    }

    func saveArticle(_ article: Article) -> Future<Result<Void, RNewsError>>{
        fatalError("should not have called saveArticle?")
    }

    var lastDeletedArticle: Article? = nil
    var deleteArticlePromises: [Promise<Result<Void, RNewsError>>] = []
    func deleteArticle(_ article: Article) -> Future<Result<Void, RNewsError>> {
        lastDeletedArticle = article
        article.feed?.removeArticle(article)
        article.feed = nil
        let promise = Promise<Result<Void, RNewsError>>()
        deleteArticlePromises.append(promise)
        return promise.future
    }

    var lastArticleMarkedRead: Article? = nil
    var markArticleReadPromises: [Promise<Result<Void, RNewsError>>] = []
    func markArticle(_ article: Article, asRead read: Bool) -> Future<Result<Void, RNewsError>> {
        lastArticleMarkedRead = article
        article.read = read
        let promise = Promise<Result<Void, RNewsError>>()
        markArticleReadPromises.append(promise)
        return promise.future
    }

    var didUpdateFeeds = false
    var updateFeedsCompletion: ([Feed], [NSError]) -> (Void) = {_ in }
    func updateFeeds(_ callback: @escaping ([Feed], [NSError]) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = callback
    }

    var didUpdateFeed: Feed? = nil
    var updateSingleFeedCallback: (Feed, NSError?) -> (Void) = {_ in }
    func updateFeed(_ feed: Feed, callback: @escaping (Feed?, NSError?) -> (Void)) {
        didUpdateFeed = feed
        updateSingleFeedCallback = callback
    }
}

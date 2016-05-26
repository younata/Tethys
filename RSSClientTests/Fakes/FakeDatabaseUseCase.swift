import Foundation
import CBGPromise
import Result
@testable import rNewsKit

class FakeDatabaseUseCase: DatabaseUseCase {
    var _databaseUpdateAvailable = false
    func databaseUpdateAvailable() -> Bool {
        return self._databaseUpdateAvailable
    }

    var performDatabaseUpdatesProgress: (Double -> Void)?
    var perfomDatabaseUpdatesCallback: (Void -> Void)?
    func performDatabaseUpdates(progress: Double -> Void, callback: Void -> Void) {
        self.performDatabaseUpdatesProgress = progress
        self.perfomDatabaseUpdatesCallback = callback
    }

    var tagsList: [String] = []
    func allTags(callback: ([String]) -> (Void)) {
        callback(tagsList)
    }

    var feedsList: [Feed]? = nil
    var didAskForFeeds = false
    var feedsCallback: (([Feed]) -> (Void))? = nil
    func feeds(callback: ([Feed]) -> (Void)) {
        didAskForFeeds = true
        feedsCallback = callback
        if let feedsList = feedsList {
            return callback(feedsList)
        }
    }

    var articlesOfFeedList = Array<Article>()
    func articlesOfFeeds(feeds: [Feed], matchingSearchQuery: String) -> DataStoreBackedArray<Article> {
        return DataStoreBackedArray(articlesOfFeedList)
    }

    var articlesList: [Article] = []
    func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        return callback(articlesList)
    }

    // MARK: DataWriter

    let subscribers = NSHashTable.weakObjectsHashTable()
    var subscribersArray: [DataSubscriber] {
        return self.subscribers.allObjects.flatMap { $0 as? DataSubscriber }
    }
    func addSubscriber(subscriber: DataSubscriber) {
        self.subscribers.addObject(subscriber)
    }

    var newFeedCallback: (Feed) -> (Void) = {_ in }
    var didCreateFeed = false
    func newFeed(callback: (Feed) -> (Void)) {
        didCreateFeed = true
        self.newFeedCallback = callback
    }

    var lastSavedFeed: Feed? = nil
    var saveFeedPromises: [Promise<Result<Void, RNewsError>>] = []
    func saveFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        lastSavedFeed = feed
        let promise = Promise<Result<Void, RNewsError>>()
        saveFeedPromises.append(promise)
        return promise.future
    }

    var lastDeletedFeed: Feed? = nil
    var deletedFeeds = Array<Feed>()
    var deleteFeedPromises: [Promise<Result<Void, RNewsError>>] = []
    func deleteFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        deletedFeeds.append(feed)
        lastDeletedFeed = feed
        let promise = Promise<Result<Void, RNewsError>>()
        deleteFeedPromises.append(promise)
        return promise.future
    }

    var lastFeedMarkedRead: Feed? = nil
    var markedReadFeeds = Array<Feed>()
    var markedReadPromise: Promise<Int>? = nil
    func markFeedAsRead(feed: Feed) -> Future<Int> {
        markedReadFeeds.append(feed)
        lastFeedMarkedRead = feed
        self.markedReadPromise = Promise<Int>()
        return self.markedReadPromise!.future
    }

    func saveArticle(article: Article) -> Future<Result<Void, RNewsError>>{
        fatalError("should not have called saveArticle?")
    }

    var lastDeletedArticle: Article? = nil
    var deleteArticlePromises: [Promise<Result<Void, RNewsError>>] = []
    func deleteArticle(article: Article) -> Future<Result<Void, RNewsError>> {
        lastDeletedArticle = article
        article.feed?.removeArticle(article)
        article.feed = nil
        let promise = Promise<Result<Void, RNewsError>>()
        deleteArticlePromises.append(promise)
        return promise.future
    }

    var lastArticleMarkedRead: Article? = nil
    var markArticleReadPromises: [Promise<Void>] = []
    func markArticle(article: Article, asRead read: Bool) -> Future<Void> {
        lastArticleMarkedRead = article
        article.read = read
        let promise = Promise<Void>()
        markArticleReadPromises.append(promise)
        return promise.future
    }

    var didUpdateFeeds = false
    var updateFeedsCompletion: ([Feed], [NSError]) -> (Void) = {_ in }
    func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = callback
    }

    var didUpdateFeed: Feed? = nil
    var updateSingleFeedCallback: (Feed, NSError?) -> (Void) = {_ in }
    func updateFeed(feed: Feed, callback: (Feed?, NSError?) -> (Void)) {
        didUpdateFeed = feed
        updateSingleFeedCallback = callback
    }
}

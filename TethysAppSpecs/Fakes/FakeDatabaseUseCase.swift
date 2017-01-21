import Foundation
import CBGPromise
import Result
@testable import TethysKit

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

    var allTagsPromises: [Promise<Result<[String], TethysError>>] = []
    func allTags() -> Future<Result<[String], TethysError>> {
        let promise = Promise<Result<[String], TethysError>>()
        self.allTagsPromises.append(promise)
        return promise.future
    }

    var feedsPromises: [Promise<Result<[Feed], TethysError>>] = []
    func feeds() -> Future<Result<[Feed], TethysError>> {
        let promise = Promise<Result<[Feed], TethysError>>()
        self.feedsPromises.append(promise)
        return promise.future
    }

    var articlesOfFeedList = Array<Article>()
    func articles(feed: Feed, matchingSearchQuery: String) -> DataStoreBackedArray<Article> {
        return DataStoreBackedArray(articlesOfFeedList)
    }

    var articlesMatchingQueryPromises: [Promise<Result<[Article], TethysError>>] = []
    func articlesMatchingQuery(_ query: String) -> Future<Result<[Article], TethysError>> {
        let promise = Promise<Result<[Article], TethysError>>()
        self.articlesMatchingQueryPromises.append(promise)
        return promise.future
    }

    var relatedArticlesPromises: [Promise<Result<[Article], TethysError>>] = []
    var relatedArticles: [Article] = []
    public func findRelatedArticles(to article: Article) -> Future<Result<[Article], TethysError>> {
        self.relatedArticles.append(article)

        let promise = Promise<Result<[Article], TethysError>>()
        self.relatedArticlesPromises.append(promise)
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
    var lastCreateFeedURL: URL? = nil
    var newFeedPromises: [Promise<Result<Void, TethysError>>] = []
    func newFeed(url: URL, callback: @escaping (Feed) -> (Void)) -> Future<Result<Void, TethysError>> {
        didCreateFeed = true
        lastCreateFeedURL = url
        self.newFeedCallback = callback
        let promise = Promise<Result<Void, TethysError>>()
        newFeedPromises.append(promise)
        return promise.future
    }

    var lastSavedFeed: Feed? = nil
    var saveFeedPromises: [Promise<Result<Void, TethysError>>] = []
    func saveFeed(_ feed: Feed) -> Future<Result<Void, TethysError>> {
        lastSavedFeed = feed
        let promise = Promise<Result<Void, TethysError>>()
        saveFeedPromises.append(promise)
        return promise.future
    }

    var lastDeletedFeed: Feed? = nil
    var deletedFeeds = Array<Feed>()
    var deleteFeedPromises: [Promise<Result<Void, TethysError>>] = []
    func deleteFeed(_ feed: Feed) -> Future<Result<Void, TethysError>> {
        deletedFeeds.append(feed)
        lastDeletedFeed = feed
        let promise = Promise<Result<Void, TethysError>>()
        deleteFeedPromises.append(promise)
        return promise.future
    }

    var lastFeedMarkedRead: Feed? = nil
    var markedReadFeeds: [Feed] = []
    var lastFeedMarkedReadPromise: Promise<Result<Int, TethysError>>? = nil
    func markFeedAsRead(_ feed: Feed) -> Future<Result<Int, TethysError>> {
        lastFeedMarkedRead = feed
        markedReadFeeds.append(feed)
        self.lastFeedMarkedReadPromise = Promise<Result<Int, TethysError>>()
        return self.lastFeedMarkedReadPromise!.future
    }

    var lastDeletedArticle: Article? = nil
    var deleteArticlePromises: [Promise<Result<Void, TethysError>>] = []
    func deleteArticle(_ article: Article) -> Future<Result<Void, TethysError>> {
        lastDeletedArticle = article
        article.feed?.removeArticle(article)
        article.feed = nil
        let promise = Promise<Result<Void, TethysError>>()
        deleteArticlePromises.append(promise)
        return promise.future
    }

    var lastArticleMarkedRead: Article? = nil
    var markArticleReadPromises: [Promise<Result<Void, TethysError>>] = []
    func markArticle(_ article: Article, asRead read: Bool) -> Future<Result<Void, TethysError>> {
        lastArticleMarkedRead = article
        article.read = read
        let promise = Promise<Result<Void, TethysError>>()
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

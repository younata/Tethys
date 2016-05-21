import Foundation
import CoreData
import CBGPromise
@testable import rNewsKit

class FakeDefaultDatabaseUseCase : DefaultDatabaseUseCase {
    var databaseUpdateIsAvailable = false
    override func databaseUpdateAvailable() -> Bool {
        return self.databaseUpdateIsAvailable
    }

    var performDatabaseUpdatesProgress: (Double -> Void)? = nil
    var performDatabaseUpdatesCallback: (Void -> Void)? = nil
    override func performDatabaseUpdates(progress: Double -> Void, callback: Void -> Void) {
        self.performDatabaseUpdatesProgress = progress
        self.performDatabaseUpdatesCallback = callback
    }

    var subscribers = Array<DataSubscriber>()
    override func addSubscriber(subscriber: DataSubscriber) {
        self.subscribers.append(subscriber)
    }

    var lastSavedFeed: Feed? = nil
    var saveFeedPromises: [Promise<Void>] = []
    override func saveFeed(feed: Feed) -> Future<Void> {
        lastSavedFeed = feed
        let promise = Promise<Void>()
        saveFeedPromises.append(promise)
        return promise.future
    }

    var lastDeletedFeed: Feed? = nil
    var deleteFeedPromises: [Promise<Void>] = []
    override func deleteFeed(feed: Feed) -> Future<Void> {
        lastDeletedFeed = feed
        let promise = Promise<Void>()
        deleteFeedPromises.append(promise)
        return promise.future
    }

    var lastFeedMarkedRead: Feed? = nil
    var lastMarkedReadPromise: Promise<Int>? = nil
    override func markFeedAsRead(feed: Feed) -> Future<Int> {
        lastFeedMarkedRead = feed
        self.lastMarkedReadPromise = Promise<Int>()
        return self.lastMarkedReadPromise!.future
    }

    var tagsList: [String] = []
    override func allTags(callback: ([String]) -> (Void)) {
        callback(tagsList)
    }

    var feedsList: [Feed] = []
    override func feeds(callback: ([Feed]) -> (Void)) {
        return callback(feedsList)
    }

    var articlesList: [Article] = []
    override func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        return callback(articlesList)
    }

    var lastArticleMarkedRead: Article? = nil
    var markArticleReadPromises: [Promise<Void>] = []
    override func markArticle(article: Article, asRead read: Bool) -> Future<Void> {
        lastArticleMarkedRead = article
        article.read = read
        let promise = Promise<Void>()
        markArticleReadPromises.append(promise)
        return promise.future
    }

    var lastDeletedArticle: Article? = nil
    var deleteArticlePromises: [Promise<Void>] = []
    override func deleteArticle(article: Article) -> Future<Void> {
        lastDeletedArticle = article
        article.feed?.removeArticle(article)
        article.feed = nil
        let promise = Promise<Void>()
        deleteArticlePromises.append(promise)
        return promise.future
    }

    var didUpdateFeeds = false
    var updateFeedsCompletion: ([Feed], [NSError]) -> (Void) = {_ in }
    override func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = callback
    }
}
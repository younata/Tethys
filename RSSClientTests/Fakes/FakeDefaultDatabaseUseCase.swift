import Foundation
import CBGPromise
import Result
@testable import rNewsKit

class FakeDefaultDatabaseUseCase : DefaultDatabaseUseCase {
    var databaseUpdateIsAvailable = false
    override func databaseUpdateAvailable() -> Bool {
        return self.databaseUpdateIsAvailable
    }

    var performDatabaseUpdatesProgress: ((Double) -> Void)? = nil
    var performDatabaseUpdatesCallback: ((Void) -> Void)? = nil
    override func performDatabaseUpdates(_ progress: @escaping (Double) -> Void, callback: @escaping (Void) -> Void) {
        self.performDatabaseUpdatesProgress = progress
        self.performDatabaseUpdatesCallback = callback
    }

    var subscribers = Array<DataSubscriber>()
    override func addSubscriber(_ subscriber: DataSubscriber) {
        self.subscribers.append(subscriber)
    }

    var lastSavedFeed: Feed? = nil
    var saveFeedPromises: [Promise<Result<Void, RNewsError>>] = []
    override func saveFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>> {
        lastSavedFeed = feed
        let promise = Promise<Result<Void, RNewsError>>()
        saveFeedPromises.append(promise)
        return promise.future
    }

    var lastDeletedFeed: Feed? = nil
    var deleteFeedPromises: [Promise<Result<Void, RNewsError>>] = []
    override func deleteFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>> {
        lastDeletedFeed = feed
        let promise = Promise<Result<Void, RNewsError>>()
        deleteFeedPromises.append(promise)
        return promise.future
    }

    var lastFeedMarkedRead: Feed? = nil
    var lastMarkedReadPromise: Promise<Result<Int, RNewsError>>? = nil
    override func markFeedAsRead(_ feed: Feed) -> Future<Result<Int, RNewsError>> {
        lastFeedMarkedRead = feed
        self.lastMarkedReadPromise = Promise<Result<Int, RNewsError>>()
        return self.lastMarkedReadPromise!.future
    }

    var allTagsPromises: [Promise<Result<[String], RNewsError>>] = []
    override func allTags() -> Future<Result<[String], RNewsError>> {
        let promise = Promise<Result<[String], RNewsError>>()
        self.allTagsPromises.append(promise)
        return promise.future
    }

    var feedsPromises: [Promise<Result<[Feed], RNewsError>>] = []
    override func feeds() -> Future<Result<[Feed], RNewsError>> {
        let promise = Promise<Result<[Feed], RNewsError>>()
        self.feedsPromises.append(promise)
        return promise.future
    }

    var lastArticleMarkedRead: Article? = nil
    var markArticleReadPromises: [Promise<Result<Void, RNewsError>>] = []
    override func markArticle(_ article: Article, asRead read: Bool) -> Future<Result<Void, RNewsError>> {
        lastArticleMarkedRead = article
        article.read = read
        let promise = Promise<Result<Void, RNewsError>>()
        markArticleReadPromises.append(promise)
        return promise.future
    }

    var lastDeletedArticle: Article? = nil
    var deleteArticlePromises: [Promise<Result<Void, RNewsError>>] = []
    override func deleteArticle(_ article: Article) -> Future<Result<Void, RNewsError>> {
        lastDeletedArticle = article
        article.feed?.removeArticle(article)
        article.feed = nil
        let promise = Promise<Result<Void, RNewsError>>()
        deleteArticlePromises.append(promise)
        return promise.future
    }

    var didUpdateFeeds = false
    var updateFeedsCompletion: ([Feed], [NSError]) -> (Void) = {_ in }
    override func updateFeeds(_ callback: @escaping ([Feed], [NSError]) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = callback
    }
}

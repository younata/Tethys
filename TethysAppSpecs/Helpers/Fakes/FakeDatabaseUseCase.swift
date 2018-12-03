import Foundation
import CBGPromise
import Result
@testable import TethysKit

class FakeDatabaseUseCase: DatabaseUseCase {
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

    // MARK: DataWriter

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

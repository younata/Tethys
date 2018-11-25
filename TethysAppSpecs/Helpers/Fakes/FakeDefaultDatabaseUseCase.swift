import Foundation
import CBGPromise
import Result
@testable import TethysKit

class FakeDefaultDatabaseUseCase : DefaultDatabaseUseCase {
    var databaseUpdateIsAvailable = false
    override func databaseUpdateAvailable() -> Bool {
        return self.databaseUpdateIsAvailable
    }

    var performDatabaseUpdatesProgress: ((Double) -> Void)? = nil
    var performDatabaseUpdatesCallback: (() -> Void)? = nil
    override func performDatabaseUpdates(_ progress: @escaping (Double) -> Void, callback: @escaping () -> Void) {
        self.performDatabaseUpdatesProgress = progress
        self.performDatabaseUpdatesCallback = callback
    }

    var subscribers = Array<DataSubscriber>()
    override func addSubscriber(_ subscriber: DataSubscriber) {
        self.subscribers.append(subscriber)
    }

    var lastSavedFeed: Feed? = nil
    var saveFeedPromises: [Promise<Result<Void, TethysError>>] = []
    override func saveFeed(_ feed: Feed) -> Future<Result<Void, TethysError>> {
        lastSavedFeed = feed
        let promise = Promise<Result<Void, TethysError>>()
        saveFeedPromises.append(promise)
        return promise.future
    }

    var lastDeletedFeed: Feed? = nil
    var deleteFeedPromises: [Promise<Result<Void, TethysError>>] = []
    override func deleteFeed(_ feed: Feed) -> Future<Result<Void, TethysError>> {
        lastDeletedFeed = feed
        let promise = Promise<Result<Void, TethysError>>()
        deleteFeedPromises.append(promise)
        return promise.future
    }

    var lastFeedMarkedRead: Feed? = nil
    var lastMarkedReadPromise: Promise<Result<Int, TethysError>>? = nil
    override func markFeedAsRead(_ feed: Feed) -> Future<Result<Int, TethysError>> {
        lastFeedMarkedRead = feed
        self.lastMarkedReadPromise = Promise<Result<Int, TethysError>>()
        return self.lastMarkedReadPromise!.future
    }

    var allTagsPromises: [Promise<Result<[String], TethysError>>] = []
    override func allTags() -> Future<Result<[String], TethysError>> {
        let promise = Promise<Result<[String], TethysError>>()
        self.allTagsPromises.append(promise)
        return promise.future
    }

    var feedsPromises: [Promise<Result<[Feed], TethysError>>] = []
    override func feeds() -> Future<Result<[Feed], TethysError>> {
        let promise = Promise<Result<[Feed], TethysError>>()
        self.feedsPromises.append(promise)
        return promise.future
    }

    var didUpdateFeeds = false
    var updateFeedsCompletion: ([Feed], [NSError]) -> (Void) = {_ in }
    override func updateFeeds(_ callback: @escaping ([Feed], [NSError]) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = callback
    }
}

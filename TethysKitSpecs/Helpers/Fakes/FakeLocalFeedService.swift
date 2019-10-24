import Result
import CBGPromise

@testable import TethysKit

final class FakeLocalFeedService: FakeFeedService, LocalFeedService {
    private(set) var updateFeedsCalls: [AnyCollection<Feed>] = []
    private(set) var updateFeedsPromises: [Promise<Result<AnyCollection<Feed>, TethysError>>] = []
    func updateFeeds(with feeds: AnyCollection<Feed>) -> Future<Result<AnyCollection<Feed>, TethysError>> {
        self.updateFeedsCalls.append(feeds)
        let promise = Promise<Result<AnyCollection<Feed>, TethysError>>()
        self.updateFeedsPromises.append(promise)
        return promise.future
    }

    private(set) var updateFeedFromCalls: [Feed] = []
    private(set) var updateFeedFromPromises: [Promise<Result<Feed, TethysError>>] = []
    func updateFeed(from feed: Feed) -> Future<Result<Feed, TethysError>> {
        self.updateFeedFromCalls.append(feed)
        let promise = Promise<Result<Feed, TethysError>>()
        self.updateFeedFromPromises.append(promise)
        return promise.future
    }
}


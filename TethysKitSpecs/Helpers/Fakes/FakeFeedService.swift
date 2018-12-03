import Result
import CBGPromise

import TethysKit

final class FakeFeedService: FeedService {
    private(set) var feedsPromises: [Promise<Result<AnyCollection<Feed>, TethysError>>] = []
    func feeds() -> Future<Result<AnyCollection<Feed>, TethysError>> {
        let promise = Promise<Result<AnyCollection<Feed>, TethysError>>()
        self.feedsPromises.append(promise)
        return promise.future
    }

    private(set) var articlesOfFeedCalls: [Feed] = []
    private(set) var articlesOfFeedPromises: [Promise<Result<AnyCollection<Article>, TethysError>>] = []
    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>> {
        self.articlesOfFeedCalls.append(feed)
        let promise = Promise<Result<AnyCollection<Article>, TethysError>>()
        self.articlesOfFeedPromises.append(promise)
        return promise.future
    }

    private(set) var subscribeCalls: [URL] = []
    private(set) var subscribePromises: [Promise<Result<Feed, TethysError>>] = []
    func subscribe(to url: URL) -> Future<Result<Feed, TethysError>> {
        self.subscribeCalls.append(url)
        let promise = Promise<Result<Feed, TethysError>>()
        self.subscribePromises.append(promise)
        return promise.future
    }

    private(set) var readAllOfFeedCalls: [Feed] = []
    private(set) var readAllOfFeedPromises: [Promise<Result<Void, TethysError>>] = []
    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>> {
        self.readAllOfFeedCalls.append(feed)
        let promise = Promise<Result<Void, TethysError>>()
        self.readAllOfFeedPromises.append(promise)
        return promise.future
    }

    private(set) var removeFeedCalls: [Feed] = []
    private(set) var removeFeedPromises: [Promise<Result<Void, TethysError>>] = []
    func remove(feed: Feed) -> Future<Result<Void, TethysError>> {
        self.removeFeedCalls.append(feed)
        let promise = Promise<Result<Void, TethysError>>()
        self.removeFeedPromises.append(promise)
        return promise.future
    }
}

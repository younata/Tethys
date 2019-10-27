import CBGPromise

@testable import TethysKit

final class FakeFeedCoordinator: FeedCoordinator {
    init() {
        super.init(localFeedService: FakeLocalFeedService(), networkFeedServiceProvider: { return FakeFeedService() })
    }

    var feedsPublishers: [Publisher<Result<AnyCollection<Feed>, TethysError>>] = []
    override func feeds() -> Subscription<Result<AnyCollection<Feed>, TethysError>> {
        let publisher = Publisher<Result<AnyCollection<Feed>, TethysError>>()
        self.feedsPublishers.append(publisher)
        return publisher.subscription
    }

    private(set) var articlesOfFeedCalls: [Feed] = []
    private(set) var articlesOfFeedPublishers: [Publisher<Result<AnyCollection<Article>, TethysError>>] = []
    override func articles(of feed: Feed) -> Subscription<Result<AnyCollection<Article>, TethysError>> {
        self.articlesOfFeedCalls.append(feed)
        let publisher = Publisher<Result<AnyCollection<Article>, TethysError>>()
        self.articlesOfFeedPublishers.append(publisher)
        return publisher.subscription
    }

    private(set) var subscribeCalls: [URL] = []
    private(set) var subscribePromises: [Promise<Result<Feed, TethysError>>] = []
    override func subscribe(to url: URL) -> Future<Result<Feed, TethysError>> {
        self.subscribeCalls.append(url)
        let promise = Promise<Result<Feed, TethysError>>()
        self.subscribePromises.append(promise)
        return promise.future
    }

    private(set) var readAllOfFeedCalls: [Feed] = []
    private(set) var readAllOfFeedPromises: [Promise<Result<Void, TethysError>>] = []
    override func readAll(of feed: Feed) -> Future<Result<Void, TethysError>> {
        self.readAllOfFeedCalls.append(feed)
        let promise = Promise<Result<Void, TethysError>>()
        self.readAllOfFeedPromises.append(promise)
        return promise.future
    }

    private(set) var unsubscribeCalls: [Feed] = []
    private(set) var unsubscribePromises: [Promise<Result<Void, TethysError>>] = []
    override func unsubscribe(from feed: Feed) -> Future<Result<Void, TethysError>> {
        self.unsubscribeCalls.append(feed)
        let promise = Promise<Result<Void, TethysError>>()
        self.unsubscribePromises.append(promise)
        return promise.future
    }
}

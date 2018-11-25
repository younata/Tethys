import CBGPromise
import Result
import Reachability

public protocol DatabaseUseCase {
    func databaseUpdateAvailable() -> Bool
    func performDatabaseUpdates(_ progress: @escaping (Double) -> Void, callback: @escaping () -> Void)

    func allTags() -> Future<Result<[String], TethysError>>
    @available(*, deprecated, message: "Use a FeedService")
    func feeds() -> Future<Result<[Feed], TethysError>>
    @available(*, deprecated, message: "Being Removed")
    func articles(feed: Feed, matchingSearchQuery query: String) -> DataStoreBackedArray<Article>

    func addSubscriber(_ subscriber: DataSubscriber)

    func newFeed(url: URL, callback: @escaping (Feed) -> Void) -> Future<Result<Void, TethysError>>
    func saveFeed(_ feed: Feed) -> Future<Result<Void, TethysError>>
    @available(*, deprecated, message: "Use a FeedService")
    func deleteFeed(_ feed: Feed) -> Future<Result<Void, TethysError>>
    @available(*, deprecated, message: "Use a FeedService")
    func markFeedAsRead(_ feed: Feed) -> Future<Result<Int, TethysError>>

    func updateFeeds(_ callback: @escaping ([Feed], [NSError]) -> Void)
    func updateFeed(_ feed: Feed, callback: @escaping (Feed?, NSError?) -> Void)
}

public protocol DataSubscriber: NSObjectProtocol {
    @available(*, deprecated, message: "No point")
    func markedArticles(_ articles: [Article], asRead read: Bool)

    @available(*, deprecated, message: "No point")
    func deletedArticle(_ article: Article)

    @available(*, deprecated, message: "No point")
    func deletedFeed(_ feed: Feed, feedsLeft: Int)

    func willUpdateFeeds()
    func didUpdateFeedsProgress(_ finished: Int, total: Int)
    func didUpdateFeeds(_ feeds: [Feed])
}

protocol Reachable {
    var hasNetworkConnectivity: Bool { get }
}

extension Reachability: Reachable {
    var hasNetworkConnectivity: Bool {
        return self.currentReachabilityStatus != .notReachable
    }
}

extension DatabaseUseCase {
    public func feeds(matchingTag tag: String?) -> Future<Result<[Feed], TethysError>> {
        if let theTag = tag, !theTag.isEmpty {
            return self.feeds().map { result in
                return result.map { allFeeds in
                    return allFeeds.filter { feed in
                        let tags = feed.tags
                        for t in tags {
                            if t.range(of: theTag) != nil {
                                return true
                            }
                        }
                        return false
                    }
                }
            }
        } else {
            return self.feeds()
        }
    }
}

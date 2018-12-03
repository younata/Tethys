import CBGPromise
import Result
import Reachability

public protocol DatabaseUseCase {
    func allTags() -> Future<Result<[String], TethysError>>
    @available(*, deprecated, message: "Use a FeedService")
    func feeds() -> Future<Result<[Feed], TethysError>>
    @available(*, deprecated, message: "Being Removed")
    func articles(feed: Feed, matchingSearchQuery query: String) -> DataStoreBackedArray<Article>

    func newFeed(url: URL, callback: @escaping (Feed) -> Void) -> Future<Result<Void, TethysError>>
    func saveFeed(_ feed: Feed) -> Future<Result<Void, TethysError>>
    @available(*, deprecated, message: "Use a FeedService")
    func deleteFeed(_ feed: Feed) -> Future<Result<Void, TethysError>>
    @available(*, deprecated, message: "Use a FeedService")
    func markFeedAsRead(_ feed: Feed) -> Future<Result<Int, TethysError>>

    func updateFeeds(_ callback: @escaping ([Feed], [NSError]) -> Void)
    func updateFeed(_ feed: Feed, callback: @escaping (Feed?, NSError?) -> Void)
}

protocol Reachable {
    var hasNetworkConnectivity: Bool { get }
}

extension Reachability: Reachable {
    var hasNetworkConnectivity: Bool {
        return self.connection != .none
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

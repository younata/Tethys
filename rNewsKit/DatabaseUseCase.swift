import CBGPromise
import Result
import Reachability

public protocol DatabaseUseCase {
    func databaseUpdateAvailable() -> Bool
    func performDatabaseUpdates(_ progress: @escaping (Double) -> Void, callback: @escaping (Void) -> Void)

    func allTags() -> Future<Result<[String], RNewsError>>
    func feeds() -> Future<Result<[Feed], RNewsError>>
    func articles(feed: Feed, matchingSearchQuery query: String) -> DataStoreBackedArray<Article>

    func addSubscriber(_ subscriber: DataSubscriber)

    func newFeed(url: URL, callback: @escaping (Feed) -> Void) -> Future<Result<Void, RNewsError>>
    func saveFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>>
    func deleteFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>>
    func markFeedAsRead(_ feed: Feed) -> Future<Result<Int, RNewsError>>

    func deleteArticle(_ article: Article) -> Future<Result<Void, RNewsError>>
    func markArticle(_ article: Article, asRead: Bool) -> Future<Result<Void, RNewsError>>
    func findRelatedArticles(to article: Article) -> Future<Result<[Article], RNewsError>>

    func updateFeeds(_ callback: @escaping ([Feed], [NSError]) -> Void)
    func updateFeed(_ feed: Feed, callback: @escaping (Feed?, NSError?) -> Void)
}

public protocol DataSubscriber: NSObjectProtocol {
    func markedArticles(_ articles: [Article], asRead read: Bool)

    func deletedArticle(_ article: Article)

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
    public func feeds(matchingTag tag: String?) -> Future<Result<[Feed], RNewsError>> {
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

import CBGPromise
import Result
#if os(iOS)
    import Reachability
#elseif os(OSX)
#endif

public protocol DatabaseUseCase {
    func databaseUpdateAvailable() -> Bool
    func performDatabaseUpdates(progress: Double -> Void, callback: Void -> Void)

    func allTags(callback: [String] -> Void)
    func feeds(callback: [Feed] -> Void)
    func articlesOfFeeds(feeds: [Feed], matchingSearchQuery: String) -> DataStoreBackedArray<Article>
    func articlesMatchingQuery(query: String, callback: [Article] -> Void)

    func addSubscriber(subscriber: DataSubscriber)

    func newFeed(callback: Feed -> Void)
    func saveFeed(feed: Feed) -> Future<Result<Void, RNewsError>>
    func deleteFeed(feed: Feed) -> Future<Result<Void, RNewsError>>
    func markFeedAsRead(feed: Feed) -> Future<Int>

    func saveArticle(article: Article) -> Future<Result<Void, RNewsError>>
    func deleteArticle(article: Article) -> Future<Result<Void, RNewsError>>
    func markArticle(article: Article, asRead: Bool) -> Future<Void>

    func updateFeeds(callback: ([Feed], [NSError]) -> Void)

    func updateFeed(feed: Feed, callback: (Feed?, NSError?) -> Void)
}

public protocol DataSubscriber: NSObjectProtocol {
    func markedArticles(articles: [Article], asRead read: Bool)

    func deletedArticle(article: Article)

    func deletedFeed(feed: Feed, feedsLeft: Int)

    func willUpdateFeeds()
    func didUpdateFeedsProgress(finished: Int, total: Int)
    func didUpdateFeeds(feeds: [Feed])
}

protocol Reachable {
    var hasNetworkConnectivity: Bool { get }
}

#if os(iOS)
    extension Reachability: Reachable {
        var hasNetworkConnectivity: Bool {
            return self.currentReachabilityStatus != .NotReachable
        }
    }
#endif

extension DatabaseUseCase {
    public func feedsMatchingTag(tag: String?, callback: [Feed] -> Void) {
        if let theTag = tag where !theTag.isEmpty {
            self.feeds {
                let feeds = $0.filter { feed in
                    let tags = feed.tags
                    for t in tags {
                        if t.rangeOfString(theTag) != nil {
                            return true
                        }
                    }
                    return false
                }
                callback(feeds)
            }
        } else {
            self.feeds(callback)
        }
    }
}

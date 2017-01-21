import UIKit
import TethysKit

extension UIApplication: DataSubscriber {
    public func markedArticles(_ articles: [Article], asRead read: Bool) {
        let incrementBy = (read ? -1 : 1) * articles.count
        self.applicationIconBadgeNumber += incrementBy
    }

    public func deletedArticle(_ article: Article) {
        if !article.read {
            self.applicationIconBadgeNumber -= 1
        }
    }

    public func deletedFeed(_ feed: Feed, feedsLeft: Int) {
        if feedsLeft == 0 {
            self.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
        }
        self.applicationIconBadgeNumber -= feed.unreadArticles.count
    }

    public func willUpdateFeeds() {
        self.isNetworkActivityIndicatorVisible = true
    }

    public func didUpdateFeedsProgress(_ finished: Int, total: Int) {}

    public func didUpdateFeeds(_ feeds: [Feed]) {
        self.isNetworkActivityIndicatorVisible = false
        let unreadCount = feeds.reduce(0) { $0 + $1.unreadArticles.count }
        self.applicationIconBadgeNumber = unreadCount
    }
}

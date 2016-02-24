import UIKit
import rNewsKit

extension UIApplication: DataSubscriber {
    public func markedArticles(articles: [Article], asRead read: Bool) {
        let incrementBy = (read ? -1 : 1) * articles.count
        self.applicationIconBadgeNumber += incrementBy
    }

    public func deletedArticle(article: Article) {
        if !article.read {
            self.applicationIconBadgeNumber -= 1
        }
    }

    public func deletedFeed(feed: Feed, feedsLeft: Int) {
        if feedsLeft == 0 {
            self.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
        }
        self.applicationIconBadgeNumber -= feed.unreadArticles.count
    }

    public func willUpdateFeeds() {
        self.networkActivityIndicatorVisible = true
    }

    public func didUpdateFeedsProgress(finished: Int, total: Int) {}

    public func didUpdateFeeds(feeds: [Feed]) {
        self.networkActivityIndicatorVisible = false
        let unreadCount = feeds.reduce(0) { $0 + $1.unreadArticles.count }
        self.applicationIconBadgeNumber = unreadCount
    }
}
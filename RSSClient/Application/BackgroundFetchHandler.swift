import UIKit
import Ra
import rNewsKit

public protocol BackgroundFetchHandler {
    func performFetch(notificationHandler: NotificationHandler,
        notificationSource: LocalNotificationSource,
        completionHandler: (UIBackgroundFetchResult) -> Void)
}

public struct DefaultBackgroundFetchHandler: BackgroundFetchHandler, Injectable {
    private let feedRepository: DatabaseUseCase

    public init(feedRepository: DatabaseUseCase) {
        self.feedRepository = feedRepository
    }

    public init(injector: Injector) {
        self.feedRepository = injector.create(DatabaseUseCase)!
    }

    public func performFetch(notificationHandler: NotificationHandler,
        notificationSource: LocalNotificationSource,
        completionHandler: (UIBackgroundFetchResult) -> Void) {
            var originalArticlesList = [String]()
            let lock = NSLock()
            lock.lock()
            feedRepository.feeds {feeds in
                originalArticlesList = feeds.reduce([]) { return $0 + $1.articlesArray }.map { return $0.identifier }
                lock.unlock()
            }

            feedRepository.updateFeeds {newFeeds, errors in
                guard errors.isEmpty else {
                    completionHandler(.Failed)
                    return
                }
                guard lock.lockBeforeDate(NSDate(timeIntervalSinceNow: 5)) else {
                    completionHandler(.Failed)
                    return
                }
                lock.unlock()
                let currentArticleList: [Article] = newFeeds.reduce([]) { return $0 + Array($1.articlesArray) }
                guard currentArticleList.count != originalArticlesList.count else { completionHandler(.NoData); return }
                let filteredArticleList: [Article] = currentArticleList.filter {
                    return !originalArticlesList.contains($0.identifier)
                }

                if filteredArticleList.count > 0 {
                    for article in filteredArticleList {
                        notificationHandler.sendLocalNotification(notificationSource, article: article)
                    }
                    completionHandler(.NewData)
                } else { completionHandler(.NoData) }

                originalArticlesList = []
            }
    }
}

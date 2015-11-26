import UIKit
import Ra
import rNewsKit

public class BackgroundFetchHandler: NSObject {
    private lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    private lazy var dataRetriever: DataRetriever? = {
        return self.injector?.create(DataRetriever.self) as? DataRetriever
    }()

    public func performFetch(notificationHandler: NotificationHandler,
        notificationSource: LocalNotificationSource,
        completionHandler: (UIBackgroundFetchResult) -> Void) {
            guard let writer = self.dataWriter, let reader = self.dataRetriever else {
                completionHandler(.Failed)
                return
            }
            var originalArticlesList = [String]()
            let lock = NSLock()
            lock.lock()
            reader.feeds {feeds in
                originalArticlesList = feeds.reduce([]) { return $0 + $1.articlesArray }.map { return $0.identifier }
                lock.unlock()
            }

            writer.updateFeeds {newFeeds, errors in
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

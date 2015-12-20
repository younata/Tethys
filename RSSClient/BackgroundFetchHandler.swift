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

    private lazy var timer: Timer? = {
        return self.injector?.create(Timer.self) as? Timer
    }()

    public func performFetch(notificationHandler: NotificationHandler, notificationSource: LocalNotificationSource, completionHandler: (UIBackgroundFetchResult) -> Void) {
        guard let writer = self.dataWriter, let reader = self.dataRetriever, let timer = self.timer else {
            completionHandler(.Failed)
            return
        }
        timer.setTimer(27) {
            writer.cancelUpdateFeeds()
            completionHandler(.Failed)
        }
        var originalArticlesList = [String]()
        let lock = NSLock()
        lock.lock()
        reader.feeds {feeds in
            originalArticlesList = feeds.reduce([]) { return $0 + $1.articles }.map { return $0.identifier }
            lock.unlock()
        }

        writer.updateFeeds {newFeeds, errors in
            guard errors.isEmpty else {
                timer.cancel()
                completionHandler(.Failed)
                return
            }
            guard lock.lockBeforeDate(NSDate(timeIntervalSinceNow: 5)) else {
                timer.cancel()
                completionHandler(.Failed)
                return
            }
            lock.unlock()
            timer.cancel()
            let currentArticleList: [Article] = newFeeds.reduce([]) { return $0 + $1.articles }
            if (currentArticleList.count == originalArticlesList.count) {
                completionHandler(.NoData)
                return
            }
            let filteredArticleList: [Article] = currentArticleList.filter{
                return !originalArticlesList.contains($0.identifier)
            }

            if (filteredArticleList.count > 0) {
                for article in filteredArticleList {
                    notificationHandler.sendLocalNotification(notificationSource, article: article)
                }
                completionHandler(.NewData)
            } else {
                completionHandler(.NoData)
            }

            originalArticlesList = []
        }
    }
}
import UIKit
import Ra
import rNewsKit

public class BackgroundFetchHandler: NSObject {
    lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    lazy var dataRetriever: DataRetriever? = {
        return self.injector?.create(DataRetriever.self) as? DataRetriever
    }()

    public func performFetch(notificationHandler: NotificationHandler, notificationSource: LocalNotificationSource, completionHandler: (UIBackgroundFetchResult) -> Void) {
        guard let writer = self.dataWriter, let reader = self.dataRetriever else {
            completionHandler(.Failed)
            return
        }
        reader.feeds {feeds in
            let originalList: [String] = feeds.reduce([]) { return $0 + $1.articles }.map { return $0.identifier }

            writer.updateFeeds {feeds, errors in
                guard errors.isEmpty else {
                    completionHandler(.Failed)
                    return
                }
                reader.feeds {newFeeds in
                    let currentArticleList: [Article] = newFeeds.reduce([]) { return $0 + $1.articles }
                    if (currentArticleList.count == originalList.count) {
                        completionHandler(.NoData)
                        return
                    }
                    let filteredArticleList: [Article] = currentArticleList.filter{
                        return !originalList.contains($0.identifier)
                    }

                    if (filteredArticleList.count > 0) {
                        for article in filteredArticleList {
                            notificationHandler.sendLocalNotification(notificationSource, article: article)
                        }
                        completionHandler(.NewData)
                    } else {
                        completionHandler(.NoData)
                    }
                }
            }
        }
    }
}
import UIKit
import Ra

public class BackgroundFetchHandler: NSObject {
    lazy var dataManager: DataManager? = {
        return self.injector?.create(DataManager.self) as? DataManager
    }()
    public func performFetch(notificationHandler: NotificationHandler, notificationSource: LocalNotificationSource, completionHandler: (UIBackgroundFetchResult) -> Void) {
        guard let dataManager = self.dataManager else {
            completionHandler(.Failed)
            return
        }
        let originalList: [String] = dataManager.feeds().reduce([]) { return $0 + $1.articles }.map { return $0.identifier }
        dataManager.updateFeedsInBackground {error in
            guard error == nil else {
                completionHandler(.Failed)
                return
            }
            let currentArticleList: [Article] = dataManager.feeds().reduce([]) { return $0 + $1.articles }
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
import UIKit
import Ra

public class BackgroundFetchHandler: NSObject {
    lazy var dataRepository: DataRepository? = {
        return self.injector?.create(DataRepository.self) as? DataRepository
    }()
    public func performFetch(notificationHandler: NotificationHandler, notificationSource: LocalNotificationSource, completionHandler: (UIBackgroundFetchResult) -> Void) {
        guard let repository = self.dataRepository else {
            completionHandler(.Failed)
            return
        }
        repository.feeds {feeds in
            let originalList: [String] = feeds.reduce([]) { return $0 + $1.articles }.map { return $0.identifier }

            repository.updateFeeds {error in
                guard error == nil else {
                    completionHandler(.Failed)
                    return
                }
                repository.feeds {newFeeds in
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
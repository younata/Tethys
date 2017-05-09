import UIKit
import Ra
import TethysKit
import Result

public protocol BackgroundFetchHandler {
    func performFetch(_ notificationHandler: NotificationHandler,
                      notificationSource: LocalNotificationSource,
                      completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
}

public struct DefaultBackgroundFetchHandler: BackgroundFetchHandler, Injectable {
    private let feedRepository: DatabaseUseCase

    public init(feedRepository: DatabaseUseCase) {
        self.feedRepository = feedRepository
    }

    public init(injector: Injector) {
        self.feedRepository = injector.create(DatabaseUseCase.self)!
    }

    public func performFetch(_ notificationHandler: NotificationHandler,
                             notificationSource: LocalNotificationSource,
                             completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let articlesIdentifierPromise = self.feedRepository.feeds().map { result -> [String] in
            if case let Result.success(feeds) = result {
                return feeds.reduce([]) {
                    return $0 + $1.articlesArray
                    }.map {
                        return $0.identifier
                }
            } else {
                return []
            }
        }

        feedRepository.updateFeeds {newFeeds, errors in
            guard errors.isEmpty else {
                completionHandler(.failed)
                return
            }
            _ = articlesIdentifierPromise.then { originalArticlesList in
                let currentArticleList: [Article] = newFeeds.reduce([]) { return $0 + Array($1.articlesArray) }
                guard currentArticleList.count != originalArticlesList.count else {
                    completionHandler(.noData)
                    return
                }
                let filteredArticleList: [Article] = currentArticleList.filter {
                    return !originalArticlesList.contains($0.identifier)
                }

                if filteredArticleList.count > 0 {
                    for article in filteredArticleList {
                        notificationHandler.sendLocalNotification(notificationSource, article: article)
                    }
                    completionHandler(.newData)
                } else { completionHandler(.noData) }
            }
        }
    }
}

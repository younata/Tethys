import UIKit
import Ra
import rNewsKit
import CBGPromise
import Result

public protocol NotificationHandler {
    func enableNotifications(_ notificationSource: LocalNotificationSource)
    func handleLocalNotification(_ notification: UILocalNotification, window: UIWindow)
    func handleAction(_ identifier: String?, notification: UILocalNotification)
    func sendLocalNotification(_ notificationSource: LocalNotificationSource, article: Article)
}

public struct LocalNotificationHandler: NotificationHandler, Injectable {
    private let feedRepository: DatabaseUseCase

    public init(feedRepository: DatabaseUseCase) {
        self.feedRepository = feedRepository
    }

    public init(injector: Injector) {
        self.init(feedRepository: injector.create(kind: DatabaseUseCase.self)!)
    }

    public func enableNotifications(_ notificationSource: LocalNotificationSource) {
        let markReadAction = UIMutableUserNotificationAction()
        markReadAction.identifier = "read"
        markReadAction.title = NSLocalizedString("NotificationHandler_LocalNotification_MarkRead_Action", comment: "")
        markReadAction.activationMode = .background
        markReadAction.isAuthenticationRequired = false

        let category = UIMutableUserNotificationCategory()
        category.identifier = "default"
        category.setActions([markReadAction], for: .minimal)
        category.setActions([markReadAction], for: .default)

        let types = UIUserNotificationType.badge.union(.alert).union(.sound)
        let notificationSettings = UIUserNotificationSettings(types: types,
            categories: Set<UIUserNotificationCategory>([category]))

        notificationSource.notificationSettings = notificationSettings
    }

    public func handleLocalNotification(_ notification: UILocalNotification, window: UIWindow) {
        guard let userInfo = notification.userInfo else { return }

        _ = self.articleFromUserInfo(userInfo as! [String : Any]).then { result in
            if case let Result.success(article) = result {
                self.showArticle(article, window: window)
            }
        }
    }

    public func handleAction(_ identifier: String?, notification: UILocalNotification) {
        guard let userInfo = notification.userInfo, identifier == "read" else { return }

        _ = self.articleFromUserInfo(userInfo as! [String : Any]).then {
            if case let Result.success(article) = $0 {
                _ = self.feedRepository.markArticle(article, asRead: true)
            }
        }
    }

    public func sendLocalNotification(_ notificationSource: LocalNotificationSource, article: Article) {
        let note = UILocalNotification()
        let alertTitle = NSLocalizedString("NotificationHandler_LocalNotification_MarkRead_Title", comment: "")
        note.alertBody = NSString.localizedStringWithFormat(alertTitle as NSString,
            article.feed?.displayTitle ?? "",
            article.title) as String

        let feedID = article.feed?.identifier ?? ""
        let articleID = article.identifier

        let dict = ["feed": feedID, "article": articleID]
        note.userInfo = dict
        note.fireDate = Date()
        note.category = "default"
        notificationSource.scheduleNote(note)
    }

    private func articleFromUserInfo(_ userInfo: [String: Any]) -> Future<Result<Article, RNewsError>> {
        guard let feedID = userInfo["feed"] as? String,
              let articleID = userInfo["article"] as? String else {
                let promise = Promise<Result<Article, RNewsError>>()
                promise.resolve(.failure(.database(.entryNotFound)))
                return promise.future
        }
        return self.feedRepository.feeds().map { result -> Result<Article, RNewsError> in
            switch result {
            case let .success(feeds):
                let feed = feeds.objectPassingTest({ $0.identifier == feedID })
                if let article = feed?.articlesArray.filter({ $0.identifier == articleID }).first {
                    return .success(article)
                }
                return .failure(.database(.entryNotFound))
            case let .failure(error):
                return .failure(error)
            }
        }
    }

    private func showArticle(_ article: Article, window: UIWindow) {
        let splitView = window.rootViewController as? UISplitViewController
        if let nc = splitView?.viewControllers.first as? UINavigationController,
            let feedsView = nc.viewControllers.first as? FeedsTableViewController,
            let feed = article.feed {
                nc.popToRootViewController(animated: false)
                let al = feedsView.showFeed(feed, animated: false)
                _ = al.showArticle(article)
        }
    }
}

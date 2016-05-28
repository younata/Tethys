import UIKit
import Ra
import rNewsKit
import CBGPromise
import Result

public protocol NotificationHandler {
    func enableNotifications(notificationSource: LocalNotificationSource)
    func handleLocalNotification(notification: UILocalNotification, window: UIWindow)
    func handleAction(identifier: String?, notification: UILocalNotification)
    func sendLocalNotification(notificationSource: LocalNotificationSource, article: Article)
}

public struct LocalNotificationHandler: NotificationHandler, Injectable {
    private let feedRepository: DatabaseUseCase

    public init(feedRepository: DatabaseUseCase) {
        self.feedRepository = feedRepository
    }

    public init(injector: Injector) {
        self.init(feedRepository: injector.create(DatabaseUseCase)!)
    }

    public func enableNotifications(notificationSource: LocalNotificationSource) {
        let markReadAction = UIMutableUserNotificationAction()
        markReadAction.identifier = "read"
        markReadAction.title = NSLocalizedString("NotificationHandler_LocalNotification_MarkRead_Action", comment: "")
        markReadAction.activationMode = .Background
        markReadAction.authenticationRequired = false

        let category = UIMutableUserNotificationCategory()
        category.identifier = "default"
        category.setActions([markReadAction], forContext: .Minimal)
        category.setActions([markReadAction], forContext: .Default)

        let types = UIUserNotificationType.Badge.union(.Alert).union(.Sound)
        let notificationSettings = UIUserNotificationSettings(forTypes: types,
            categories: Set<UIUserNotificationCategory>([category]))

        notificationSource.notificationSettings = notificationSettings
    }

    public func handleLocalNotification(notification: UILocalNotification, window: UIWindow) {
        guard let userInfo = notification.userInfo else { return }

        self.articleFromUserInfo(userInfo).then { result in
            if case let Result.Success(article) = result {
                self.showArticle(article, window: window)
            }
        }
    }

    public func handleAction(identifier: String?, notification: UILocalNotification) {
        guard let userInfo = notification.userInfo where identifier == "read" else { return }

        self.articleFromUserInfo(userInfo).then {
            if case let Result.Success(article) = $0 {
                self.feedRepository.markArticle(article, asRead: true)
            }
        }
    }

    public func sendLocalNotification(notificationSource: LocalNotificationSource, article: Article) {
        let note = UILocalNotification()
        let alertTitle = NSLocalizedString("NotificationHandler_LocalNotification_MarkRead_Title", comment: "")
        note.alertBody = NSString.localizedStringWithFormat(alertTitle,
            article.feed?.displayTitle ?? "",
            article.title ?? "") as String

        let feedID = article.feed?.identifier ?? ""
        let articleID = article.identifier

        let dict = ["feed": feedID, "article": articleID]
        note.userInfo = dict
        note.fireDate = NSDate()
        note.category = "default"
        notificationSource.scheduleNote(note)
    }

    private func articleFromUserInfo(userInfo: [NSObject: AnyObject]) -> Future<Result<Article, RNewsError>> {
        guard let feedID = userInfo["feed"] as? String,
              articleID = userInfo["article"] as? String else {
                let promise = Promise<Result<Article, RNewsError>>()
                promise.resolve(.Failure(.Database(.EntryNotFound)))
                return promise.future
        }
        return self.feedRepository.feeds().map { result -> Result<Article, RNewsError> in
            switch result {
            case let .Success(feeds):
                let feed = feeds.filter({ $0.identifier == feedID }).first
                if let article = feed?.articlesArray.filter({ $0.identifier == articleID }).first {
                    return .Success(article)
                }
                return .Failure(.Database(.EntryNotFound))
            case let .Failure(error):
                return .Failure(error)
            }
        }
    }

    private func showArticle(article: Article, window: UIWindow) {
        let splitView = window.rootViewController as? UISplitViewController
        if let nc = splitView?.viewControllers.first as? UINavigationController,
            feedsView = nc.viewControllers.first as? FeedsTableViewController,
            feed = article.feed {
                nc.popToRootViewControllerAnimated(false)
                let al = feedsView.showFeeds([feed], animated: false)
                al.showArticle(article)
        }
    }
}

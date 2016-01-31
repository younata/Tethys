import UIKit
import Ra
import rNewsKit

public class NotificationHandler: NSObject {

    private lazy var feedRepository: FeedRepository? = {
        return self.injector?.create(FeedRepository)
    }()

    public func enableNotifications(var notificationSource: LocalNotificationSource) {
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

        self.articleFromUserInfo(userInfo) { self.showArticle($0, window: window) }
    }

    public func handleAction(identifier: String?, notification: UILocalNotification) {
        guard let userInfo = notification.userInfo where identifier == "read" else { return }

        self.articleFromUserInfo(userInfo) { self.feedRepository?.markArticle($0, asRead: true) }
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

    private func articleFromUserInfo(userInfo: [NSObject: AnyObject], callback: (Article) -> (Void)) {
        guard let feedRepository = self.feedRepository,
              let feedID = userInfo["feed"] as? String,
              let articleID = userInfo["article"] as? String else {
                return
        }
        feedRepository.feeds {feeds in
            let feed = feeds.filter({ $0.identifier == feedID }).first
            if let article = feed?.articlesArray.filter({ $0.identifier == articleID }).first {
                callback(article)
            }
        }
    }

    private func showArticle(article: Article, window: UIWindow) {
        let splitView = window.rootViewController as? UISplitViewController
        if let nc = splitView?.viewControllers.first as? UINavigationController,
            let feedsView = nc.viewControllers.first as? FeedsTableViewController,
            let feed = article.feed {
                nc.popToRootViewControllerAnimated(false)
                let al = feedsView.showFeeds([feed], animated: false)
                al.showArticle(article)
        }
    }
}

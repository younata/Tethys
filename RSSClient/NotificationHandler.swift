import UIKit
import Ra
import rNewsKit

public class NotificationHandler: NSObject {

    private lazy var dataRetriever: DataRetriever? = {
        return self.injector?.create(DataRetriever.self) as? DataRetriever
    }()

    private lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    public func enableNotifications(var notificationSource: LocalNotificationSource) {
        let markReadAction = UIMutableUserNotificationAction()
        markReadAction.identifier = "read"
        markReadAction.title = NSLocalizedString("Mark Read", comment: "")
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
        if let userInfo = notification.userInfo {
            self.feedAndArticleFromUserInfo(userInfo) {_, article in
                if let article = article {
                    self.showArticle(article, window: window)
                }
            }
        }
    }

    public func handleAction(identifier: String?, notification: UILocalNotification) {
        if let userInfo = notification.userInfo where identifier == "read" {
            self.feedAndArticleFromUserInfo(userInfo) {_, article in
                if let article = article {
                    self.dataWriter?.markArticle(article, asRead: true)
                }
            }
        }
    }

    public func sendLocalNotification(notificationSource: LocalNotificationSource, article: Article) {
        let note = UILocalNotification()
        note.alertBody = NSString.localizedStringWithFormat("New article in %@: %@",
            article.feed?.title ?? "", article.title ?? "") as String

        let feedID = article.feed?.identifier ?? ""
        let articleID = article.identifier

        let dict = ["feed": feedID, "article": articleID]
        note.userInfo = dict
        note.fireDate = NSDate()
        note.category = "default"
        notificationSource.scheduleNote(note)
    }

    private func feedAndArticleFromUserInfo(userInfo: [NSObject : AnyObject], callback: (Feed?, Article?) -> (Void)) {
        guard let _ = self.dataRetriever,
              let feedID = userInfo["feed"] as? String,
              let articleID = userInfo["article"] as? String else {
                callback(nil, nil)
                return
        }
        self.dataRetriever?.feeds {feeds in
            let feed = feeds.filter({ $0.identifier == feedID }).first
            let article = feed?.articles.filter({ $0.identifier == articleID }).first
            callback(feed, article)
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
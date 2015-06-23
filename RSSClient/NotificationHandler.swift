import UIKit
import Ra

public class NotificationHandler: NSObject {

    private lazy var dataManager: DataManager? = {
        return self.injector?.create(DataManager.self) as? DataManager
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
            let (_, article) = feedAndArticleFromUserInfo(userInfo)
            showArticle(article, window: window)
        }
    }

    public func handleAction(identifier: String?, notification: UILocalNotification) {
        if let userInfo = notification.userInfo {
            let (_, article) = feedAndArticleFromUserInfo(userInfo)
            if identifier == "read" {
                dataManager?.markArticle(article, asRead: true)
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

    private func feedAndArticleFromUserInfo(userInfo: [NSObject : AnyObject]) -> (Feed, Article) {
        let feedID = (userInfo["feed"] as! String)
        let dataManager = self.injector!.create(DataManager.self) as! DataManager
        let feed: Feed = dataManager.feeds().filter {
            return $0.identifier == feedID
        }.first!
        let articleID = (userInfo["article"] as! String)
        let article: Article = feed.articles.filter {
            return $0.identifier == articleID
        }.first!
        return (feed, article)
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
import UIKit
import Ra

public class NotificationHandler: NSObject {

    private lazy var dataManager: DataManager? = {
        return self.injector?.create(DataManager.self) as? DataManager
    }()

    public func enableNotifications(application: UIApplication) {
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
        application.registerUserNotificationSettings(notificationSettings)
    }

    public func handleLocalNotification(notification: UILocalNotification, window: UIWindow) {
        if let userInfo = notification.userInfo {
            let (_, article) = feedAndArticleFromUserInfo(userInfo)
            showArticle(article, window: window)
        }
    }

    public func handleAction(identifier: String?, notification: UILocalNotification,
        window: UIWindow, completionHandler: () -> Void) {
            if let userInfo = notification.userInfo {
                let (_, article) = feedAndArticleFromUserInfo(userInfo)
                if identifier == "read" {
//                    let dataManager = self.injector!.create(DataManager.self) as! DataManager
//                    dataManager.readArticle(article)
                }
            }
    }

    public func sendLocalNotification(application: UIApplication, article: Article) {
        let note = UILocalNotification()
        note.alertBody = NSString.localizedStringWithFormat("New article in %@: %@",
            article.feed?.title ?? "", article.title ?? "") as String

//        let feedID = article.feed!.objectID.URIRepresentation().absoluteString!
//        let articleID = article.objectID.URIRepresentation().absoluteString!

//        let dict = ["feed": feedID, "article": articleID]
//        note.userInfo = dict
        note.fireDate = NSDate()
        note.category = "default"
        if let existingNotes = application.scheduledLocalNotifications {
            application.scheduledLocalNotifications = existingNotes + [note]
        }
        application.presentLocalNotificationNow(note)
    }

    private func feedAndArticleFromUserInfo(userInfo: [NSObject : AnyObject]) -> (Feed, Article) {
        let feedID = (userInfo["feed"] as! String)
        let dataManager = self.injector!.create(DataManager.self) as! DataManager
        let feed: Feed = dataManager.feeds().filter {
            return $0.feedID?.URIRepresentation().absoluteString == feedID
        }.first!
        let articleID = (userInfo["article"] as! String)
        let article: Article = feed.articles.filter {
            return $0.articleID?.URIRepresentation().absoluteString == articleID
        }.first!
        return (feed, article)
    }

    private func showArticle(article: Article, window: UIWindow) {
        let splitView = window.rootViewController as? UISplitViewController
        if let nc = splitView?.viewControllers.first as? UINavigationController,
            let _ = nc.viewControllers.first as? FeedsTableViewController {
                nc.popToRootViewControllerAnimated(false)
                if let _ = article.feed {
//                    let al = ftvc.showFeeds([feed], animated: false)
//                    al.showArticle(article)
                }
        }
    }
}
import UIKit
import Ra
import rNewsKit
import CoreSpotlight

@UIApplicationMain
public class AppDelegate: UIResponder, UIApplicationDelegate {

    public lazy var window: UIWindow? = {
        let window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window.backgroundColor = UIColor.whiteColor()
        window.makeKeyAndVisible()
        return window
    }()

    public lazy var anInjector: Ra.Injector = {
        let appModule = InjectorModule()
        let kitModule = KitModule()
        return Ra.Injector(module: appModule, kitModule)
    }()

    lazy var dataRetriever: DataRetriever? = {
        return self.anInjector.create(DataRetriever.self) as? DataRetriever
    }()

    lazy var notificationHandler: NotificationHandler? = {
        self.anInjector.create(NotificationHandler.self) as? NotificationHandler
    }()

    lazy var backgroundFetchHandler: BackgroundFetchHandler? = {
        self.anInjector.create(BackgroundFetchHandler.self) as? BackgroundFetchHandler
    }()

    lazy var splitDelegate: SplitDelegate = {
        let splitDelegate = SplitDelegate(splitViewController: self.splitView)
        self.anInjector.bind(SplitDelegate.self, to: splitDelegate)
        return splitDelegate
    }()

    private lazy var splitView: UISplitViewController = UISplitViewController()

    public func application(application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
            UINavigationBar.appearance().tintColor = UIColor.darkGreenColor()
            UIBarButtonItem.appearance().tintColor = UIColor.darkGreenColor()
            UITabBar.appearance().tintColor = UIColor.darkGreenColor()

            let feeds = self.anInjector.create(FeedsTableViewController.self) as! FeedsTableViewController
            let master = UINavigationController(rootViewController: feeds)
            let detail = UINavigationController(rootViewController: ArticleViewController())

            for nc in [master, detail] {
                nc.navigationBar.translucent = true
            }

            splitView.viewControllers = [master, detail]
            splitView.delegate = splitDelegate
            self.window?.rootViewController = splitView

            notificationHandler?.enableNotifications(application)

            return true
    }

    public func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        if let window = self.window {
            notificationHandler?.handleLocalNotification(notification, window: window)
        }
    }

    public func application(application: UIApplication, handleActionWithIdentifier identifier: String?,
        forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
            notificationHandler?.handleAction(identifier, notification: notification)
            completionHandler()
    }

    public func application(application: UIApplication,
        performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
            if let noteHandler = self.notificationHandler {
                self.backgroundFetchHandler?.performFetch(noteHandler, notificationSource: application, completionHandler: completionHandler)
            }
    }

    public func application(application: UIApplication,
        continueUserActivity userActivity: NSUserActivity,
        restorationHandler: ([AnyObject]?) -> Void) -> Bool {
            let type = userActivity.activityType
            if type == "com.rachelbrindle.rssclient.article",
                let splitView = self.window?.rootViewController as? UISplitViewController,
                let navController = splitView.viewControllers.first as? UINavigationController,
                let feedsViewController = navController.viewControllers.first as? FeedsTableViewController,
                let userInfo = userActivity.userInfo,
                let feedID = userInfo["feed"] as? String,
                let articleID = userInfo["article"] as? String {
                    self.dataRetriever?.feeds {feeds in
                        if let feed = feeds.filter({ return $0.identifier == feedID }).first,
                            let article = feed.articles.filter({ $0.identifier == articleID }).first {
                                navController.popToRootViewControllerAnimated(false)
                                let al = feedsViewController.showFeeds([feed], animated: false)
                                restorationHandler([al.showArticle(article, animated: false)])
                        }
                    }
                    return true
            }
            if #available(iOS 9.0, *) {
                if type == CSSearchableItemActionType,
                    let uniqueID = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                    let splitView = self.window?.rootViewController as? UISplitViewController,
                    let navController = splitView.viewControllers.first as? UINavigationController,
                    let feedsViewController = navController.viewControllers.first as? FeedsTableViewController {
                        self.dataRetriever?.feeds {feeds in
                            guard let article = feeds.reduce(Array<Article>(), combine: {articles, feed in
                                return articles + feed.articles
                            }).filter({ article in
                                    return article.identifier == uniqueID
                            }).first, let feed = article.feed else {
                                return
                            }
                            navController.popToRootViewControllerAnimated(false)
                            let al = feedsViewController.showFeeds([feed], animated: false)
                            restorationHandler([al.showArticle(article, animated: false)])
                        }
                        return true
                }
            }
            return false
    }

    public func applicationDidEnterBackground(application: UIApplication) {
//        dataManager.backgroundObjectContext.save(nil)
    }

    public func applicationWillTerminate(application: UIApplication) {
//        dataManager.backgroundObjectContext.save(nil)
    }
}


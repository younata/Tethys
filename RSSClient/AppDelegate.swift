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

    private lazy var feedRepository: FeedRepository? = {
        return self.anInjector.create(FeedRepository)
    }()

    private lazy var notificationHandler: NotificationHandler? = {
        self.anInjector.create(NotificationHandler)
    }()

    private lazy var backgroundFetchHandler: BackgroundFetchHandler? = {
        self.anInjector.create(BackgroundFetchHandler)
    }()

    internal lazy var splitView: SplitViewController = {
        let splitView = self.anInjector.create(SplitViewController)!
        self.anInjector.bind(SplitViewController.self, toInstance: splitView)
        return splitView
    }()

    public func application(application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
            UINavigationBar.appearance().tintColor = UIColor.darkGreenColor()
            UIBarButtonItem.appearance().tintColor = UIColor.darkGreenColor()
            UITabBar.appearance().tintColor = UIColor.darkGreenColor()

            if NSProcessInfo.processInfo().environment["deleteDocuments"] == "1" {
                let url = NSURL(string: "file://\(NSHomeDirectory())")!.URLByAppendingPathComponent("Documents")
                _ = try? NSFileManager.defaultManager().removeItemAtURL(url)
            }

            if NSClassFromString("XCTestCase") != nil && launchOptions?["test"] as? Bool != true {
                self.window?.rootViewController = UIViewController()
                return true
            }

            self.createControllerHierarchy()

            if let feedRepository = self.feedRepository {
                feedRepository.addSubscriber(application)
                let userDefaults = NSUserDefaults.standardUserDefaults()
                if !userDefaults.boolForKey("firstLaunch") {
                    feedRepository.newFeed { feed in
                        feed.title = NSLocalizedString("AppDelegate_UnreadFeed_Title", comment: "")
                        feed.summary = NSLocalizedString("AppDelegate_UnreadFeed_Summary", comment: "")
                        feed.query = "function(article) {\n    return !article.read;\n}"
                    }
                    userDefaults.setBool(true, forKey: "firstLaunch")
                }
            }

            self.notificationHandler?.enableNotifications(application)

            application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)

            return true
    }

    // MARK: Quick Actions

    @available(iOS 9, *)
    public func application(application: UIApplication,
        performActionForShortcutItem shortcutItem: UIApplicationShortcutItem,
        completionHandler: (Bool) -> Void) {
            let splitView = self.window?.rootViewController as? UISplitViewController
            guard let navigationController = splitView?.viewControllers.first as? UINavigationController else {
                completionHandler(false)
                return
            }
            navigationController.popToRootViewControllerAnimated(false)

            guard let feedsViewController = navigationController.topViewController as? FeedsTableViewController else {
                completionHandler(false)
                return
            }

            if shortcutItem.type == "com.rachelbrindle.RSSClient.newfeed" {
                feedsViewController.importFromWeb()
                completionHandler(true)
            } else if let feedTitle = shortcutItem.userInfo?["feed"] as? String
                where shortcutItem.type == "com.rachelbrindle.RSSClient.viewfeed" {
                    self.feedRepository?.feeds {feeds in
                        if let feed = feeds.filter({ return $0.title == feedTitle }).first {
                            feedsViewController.showFeeds([feed], animated: false)
                            completionHandler(true)
                        }
                    }
            } else {
                completionHandler(false)
            }
    }

    // MARK: Local Notifications

    public func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        if let window = self.window {
            self.notificationHandler?.handleLocalNotification(notification, window: window)
        }
    }

    public func application(application: UIApplication, handleActionWithIdentifier identifier: String?,
        forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
            self.notificationHandler?.handleAction(identifier, notification: notification)
            completionHandler()
    }

    // MARK: Background Fetch

    public func application(application: UIApplication,
        performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
            if let noteHandler = self.notificationHandler {
                self.backgroundFetchHandler?.performFetch(noteHandler,
                    notificationSource: application,
                    completionHandler: completionHandler)
            } else {
                completionHandler(.NoData)
            }
    }

    // MARK: - User Activities

    public func application(application: UIApplication,
        continueUserActivity userActivity: NSUserActivity,
        restorationHandler: ([AnyObject]?) -> Void) -> Bool {
            let type = userActivity.activityType
            if type == "com.rachelbrindle.rssclient.article",
                let userInfo = userActivity.userInfo,
                let feedTitle = userInfo["feed"] as? String,
                let articleID = userInfo["article"] as? String {
                    self.feedRepository?.feeds {feeds in
                        if let feed = feeds.filter({ return $0.title == feedTitle }).first,
                            let article = feed.articlesArray.filter({ $0.identifier == articleID }).first {
                                self.createControllerHierarchy(feed, article: article)
                        }
                    }
                    return true
            }
            if #available(iOS 9.0, *) {
                if type == CSSearchableItemActionType,
                    let uniqueID = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        self.feedRepository?.feeds {feeds in
                            guard let article = feeds.reduce(Array<Article>(), combine: {articles, feed in
                                return articles + Array(feed.articlesArray)
                            }).filter({ article in
                                    return article.identifier == uniqueID
                            }).first, let feed = article.feed else {
                                return
                            }
                            self.createControllerHierarchy(feed, article: article)
                        }
                        return true
                }
            }
            return false
    }

    // MARK: - Private

    private func createControllerHierarchy(feed: Feed? = nil, article: Article? = nil) {
        let feeds: FeedsTableViewController
        let master = self.splitView.masterNavigationController

        if let feedsController = master.viewControllers.first as? FeedsTableViewController
            where self.window?.rootViewController == self.splitView {
                feeds = feedsController
        } else {
            feeds = self.anInjector.create(FeedsTableViewController)!
            master.viewControllers = [feeds]
        }

        if let feedToShow = feed, let articleToShow = article {
            self.splitView.viewControllers = [master]
            let al = feeds.showFeeds([feedToShow], animated: false)
            al.showArticle(articleToShow, animated: false)
        } else {
            let detail = self.splitView.detailNavigationController
            let articleViewController =  self.anInjector.create(ArticleViewController)!
            detail.viewControllers = [articleViewController]
            self.splitView.viewControllers = [master, detail]
        }

        self.window?.rootViewController = splitView
    }
}

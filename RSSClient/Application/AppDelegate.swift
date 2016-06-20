import UIKit
import Ra
import rNewsKit
import Result
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
        let kitModule = KitModule()
        let appModule = InjectorModule()
        return Ra.Injector(module: appModule, kitModule)
    }()

    private lazy var feedRepository: DatabaseUseCase = {
        return self.anInjector.create(DatabaseUseCase)!
    }()

    private lazy var notificationHandler: NotificationHandler = {
        self.anInjector.create(NotificationHandler)!
    }()

    private lazy var backgroundFetchHandler: BackgroundFetchHandler = {
        self.anInjector.create(BackgroundFetchHandler)!
    }()

    internal lazy var splitView: SplitViewController = {
        let splitView = self.anInjector.create(SplitViewController)!
        self.anInjector.bind(SplitViewController.self, toInstance: splitView)
        return splitView
    }()

    private lazy var bootstrapper: Bootstrapper = {
        return BootstrapWorkFlow(window: self.window!, injector: self.anInjector)
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

            self.feedRepository.addSubscriber(application)
            self.notificationHandler.enableNotifications(application)

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
                // swiftlint:disable conditional_binding_cascade
                    self.feedRepository.feeds().then {
                        if case let Result.Success(feeds) = $0,
                            let feed = feeds.filter({ return $0.title == feedTitle }).first {
                                feedsViewController.showFeed(feed, animated: false)
                                completionHandler(true)
                        } else {
                            completionHandler(false)
                        }
                    }
                // swiftlint:enable conditional_binding_cascade
            } else {
                completionHandler(false)
            }
    }

    // MARK: Local Notifications

    public func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        if let window = self.window {
            self.notificationHandler.handleLocalNotification(notification, window: window)
        }
    }

    public func application(application: UIApplication, handleActionWithIdentifier identifier: String?,
        forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
            self.notificationHandler.handleAction(identifier, notification: notification)
            completionHandler()
    }

    // MARK: Background Fetch

    public func application(application: UIApplication,
        performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
            self.backgroundFetchHandler.performFetch(self.notificationHandler,
                notificationSource: application,
                completionHandler: completionHandler)
    }

    // MARK: - User Activities

    public func application(application: UIApplication,
        continueUserActivity userActivity: NSUserActivity,
        restorationHandler: ([AnyObject]?) -> Void) -> Bool {
            let type = userActivity.activityType
            if type == "com.rachelbrindle.rssclient.article",
                let userInfo = userActivity.userInfo,
                feedTitle = userInfo["feed"] as? String,
                articleID = userInfo["article"] as? String {
                    self.feedRepository.feeds().then() {
                        if case let Result.Success(feeds) = $0 {
                            if let feed = feeds.filter({ return $0.title == feedTitle }).first,
                                article = feed.articlesArray.filter({ $0.identifier == articleID }).first {
                                    self.createControllerHierarchy(feed, article: article)
                            }
                        }
                    }
                    return true
            }
            if #available(iOS 9.0, *) {
                if type == CSSearchableItemActionType,
                    let uniqueID = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        self.feedRepository.feeds().then {
                            guard case let Result.Success(feeds) = $0 else { return }
                            guard let article = feeds.reduce(Array<Article>(), combine: {articles, feed in
                                return articles + Array(feed.articlesArray)
                            }).filter({ article in
                                    return article.identifier == uniqueID
                            }).first, feed = article.feed else {
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
        let feedAndArticle: (Feed, Article)?
        if let feed = feed, article = article {
            feedAndArticle = (feed, article)
        } else {
            feedAndArticle = nil
        }
        self.bootstrapper.begin(feedAndArticle)
    }
}

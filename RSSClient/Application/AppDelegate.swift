import UIKit
import Ra
import rNewsKit
import Result
import CoreSpotlight

@UIApplicationMain
public final class AppDelegate: UIResponder, UIApplicationDelegate {
    public lazy var window: UIWindow? = {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor.white
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

    private lazy var analytics: Analytics = {
        self.anInjector.create(Analytics)!
    }()

    internal lazy var splitView: SplitViewController = {
        let splitView = self.anInjector.create(SplitViewController)!
        self.anInjector.bind(SplitViewController.self, toInstance: splitView)
        return splitView
    }()

    private lazy var bootstrapper: Bootstrapper = {
        return BootstrapWorkFlow(window: self.window!, injector: self.anInjector)
    }()

    public func application(_ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [NSObject: Any]?) -> Bool {
            UINavigationBar.appearance().tintColor = UIColor.darkGreen()
            UIBarButtonItem.appearance().tintColor = UIColor.darkGreen()
            UITabBar.appearance().tintColor = UIColor.darkGreen()

            if ProcessInfo.processInfo.environment["deleteDocuments"] == "1" {
                let url = URL(string: "file://\(NSHomeDirectory())")!.appendingPathComponent("Documents")
                _ = try? FileManager.default.removeItem(at: url)
            }

            if NSClassFromString("XCTestCase") != nil && launchOptions?["test"] as? Bool != true {
                self.window?.rootViewController = UIViewController()
                return true
            }

            self.createControllerHierarchy()

            self.feedRepository.addSubscriber(application)
            self.notificationHandler.enableNotifications(application)

            if launchOptions == nil || launchOptions?.isEmpty == true ||
                (launchOptions?.count == 1 && launchOptions?["test"] as? Bool == true) {
                    self.analytics.logEvent("SessionBegan", data: nil)
            }

            application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)

            return true
    }

    // MARK: Quick Actions

    @available(iOS 9, *)
    public func application(_ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void) {
            let splitView = self.window?.rootViewController as? UISplitViewController
            guard let navigationController = splitView?.viewControllers.first as? UINavigationController else {
                completionHandler(false)
                return
            }
            navigationController.popToRootViewController(animated: false)

            guard let feedsViewController = navigationController.topViewController as? FeedsTableViewController else {
                completionHandler(false)
                return
            }

            if shortcutItem.type == "com.rachelbrindle.RSSClient.newfeed" {
                feedsViewController.importFromWeb()
                self.analytics.logEvent("QuickActionUsed", data: ["kind": "Add New Feed"])
                completionHandler(true)
            } else if let feedTitle = shortcutItem.userInfo?["feed"] as? String,
                shortcutItem.type == "com.rachelbrindle.RSSClient.viewfeed" {
                // swiftlint:disable conditional_binding_cascade
                    self.feedRepository.feeds().then {
                        if case let Result.success(feeds) = $0,
                            let feed = feeds.objectPassingTest({ return $0.title == feedTitle }) {
                                feedsViewController.showFeed(feed, animated: false)
                                self.analytics.logEvent("QuickActionUsed", data: ["kind": "View Feed"])
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

    public func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        if let window = self.window {
            self.notificationHandler.handleLocalNotification(notification, window: window)
        }
    }

    public func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?,
        for notification: UILocalNotification, completionHandler: () -> Void) {
            self.notificationHandler.handleAction(identifier, notification: notification)
            completionHandler()
    }

    // MARK: Background Fetch

    public func application(_ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
            self.backgroundFetchHandler.performFetch(self.notificationHandler,
                notificationSource: application,
                completionHandler: completionHandler)
    }

    // MARK: - User Activities

    public func application(_ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: (Any?) -> Void) -> Bool {
            let type = userActivity.activityType
            if type == "com.rachelbrindle.rssclient.article",
                let userInfo = userActivity.userInfo,
                let feedTitle = userInfo["feed"] as? String,
                let articleID = userInfo["article"] as? String {
                    self.feedRepository.feeds().then() {
                        if case let Result.success(feeds) = $0 {
                            if let feed = feeds.objectPassingTest({ return $0.title == feedTitle }),
                                let article = feed.articlesArray.filter({ $0.identifier == articleID }).first {
                                    self.createControllerHierarchy(feed, article: article)
                            }
                        }
                    }
                    return true
            }
            if type == CSSearchableItemActionType,
                let uniqueID = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                    self.feedRepository.feeds().then {
                        guard case let Result.success(feeds) = $0 else { return }
                        guard let article = feeds.reduce(Array<Article>(), combine: {articles, feed in
                            return articles + Array(feed.articlesArray)
                        }).objectPassingTest({ article in
                                return article.identifier == uniqueID
                        }), let feed = article.feed else {
                            return
                        }
                        self.createControllerHierarchy(feed, article: article)
                    }
                    return true
            }
            return false
    }

    // MARK: - Private

    private func createControllerHierarchy(_ feed: Feed? = nil, article: Article? = nil) {
        let feedAndArticle: (Feed, Article)?
        if let feed = feed, let article = article {
            feedAndArticle = (feed, article)
        } else {
            feedAndArticle = nil
        }
        self.bootstrapper.begin(feedAndArticle)
    }
}

import UIKit
import Ra
import rNewsKit
import Result
import CoreSpotlight

@UIApplicationMain
public final class AppDelegate: UIResponder, UIApplicationDelegate {
    public var window: UIWindow?

    public lazy var anInjector: Ra.Injector = {
        let kitModule = KitModule()
        let appModule = InjectorModule()
        return Ra.Injector(module: appModule, kitModule)
    }()

    private lazy var feedRepository: DatabaseUseCase = {
        return self.anInjector.create(kind: DatabaseUseCase.self)!
    }()

    private lazy var notificationHandler: NotificationHandler = {
        self.anInjector.create(kind: NotificationHandler.self)!
    }()

    private lazy var backgroundFetchHandler: BackgroundFetchHandler = {
        self.anInjector.create(kind: BackgroundFetchHandler.self)!
    }()

    private lazy var analytics: Analytics = {
        self.anInjector.create(kind: Analytics.self)!
    }()

    private lazy var importUseCase: ImportUseCase = {
        self.anInjector.create(kind: ImportUseCase.self)!
    }()

    internal lazy var splitView: SplitViewController = {
        let splitView = self.anInjector.create(kind: SplitViewController.self)!
        self.anInjector.bind(kind: SplitViewController.self, toInstance: splitView)
        return splitView
    }()

    private lazy var bootstrapper: Bootstrapper = {
        return BootstrapWorkFlow(window: self.getWindow(), injector: self.anInjector)
    }()

    private func getWindow() -> UIWindow {
        if let window = self.window {
            return window
        }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor.white
        window.makeKeyAndVisible()
        self.window = window
        return window
    }

    public func application(_ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
            UINavigationBar.appearance().tintColor = UIColor.darkGreen()
            UIBarButtonItem.appearance().tintColor = UIColor.darkGreen()
            UITabBar.appearance().tintColor = UIColor.darkGreen()

            if NSClassFromString("XCTestCase") != nil &&
                launchOptions?[UIApplicationLaunchOptionsKey("test")] as? Bool != true {
                    self.getWindow().rootViewController = UIViewController()
                    return true
            }

            self.createControllerHierarchy()

            self.feedRepository.addSubscriber(application)
            self.notificationHandler.enableNotifications(application)

            if launchOptions == nil || launchOptions?.isEmpty == true ||
                (launchOptions?.count == 1 && launchOptions?[UIApplicationLaunchOptionsKey("test")] as? Bool == true) {
                    self.analytics.logEvent("SessionBegan", data: nil)
            }

            application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)

            return true
    }

    public func application(_ app: UIApplication,
                            open url: URL,
                            options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        _ = self.importUseCase.scanForImportable(url).then { item in
            if case let .opml(url, _) = item {
                _ = self.importUseCase.importItem(url)
            }
        }
        return true
    }

    // MARK: Quick Actions

    @available(iOS 9, *)
    public func application(_ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void) {
            let splitView = self.getWindow().rootViewController as? UISplitViewController
            guard let navigationController = splitView?.viewControllers.first as? UINavigationController else {
                completionHandler(false)
                return
            }
            navigationController.popToRootViewController(animated: false)

            guard let feedsViewController = navigationController.topViewController as? FeedsTableViewController else {
                completionHandler(false)
                return
            }

            if shortcutItem.type == "com.rachelbrindle.rssclient.newfeed" {
                feedsViewController.importFromWeb()
                self.analytics.logEvent("QuickActionUsed", data: ["kind": "Add New Feed"])
                completionHandler(true)
            } else if shortcutItem.type == "com.rachelbrindle.rssclient.viewfeed" {
                let feedTitle = shortcutItem.userInfo?["feed"] as? String ?? shortcutItem.localizedTitle
                // swiftlint:disable conditional_binding_cascade
                    _ = self.feedRepository.feeds().then {
                        if case let Result.success(feeds) = $0,
                            let feed = feeds.objectPassingTest({ return $0.title == feedTitle }) {
                                _ = feedsViewController.showFeed(feed, animated: false)
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
        self.notificationHandler.handleLocalNotification(notification, window: self.getWindow())
    }

    public func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?,
        for notification: UILocalNotification, completionHandler: @escaping () -> Void) {
            self.notificationHandler.handleAction(identifier, notification: notification)
            completionHandler()
    }

    // MARK: Background Fetch

    public func application(_ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
            self.backgroundFetchHandler.performFetch(self.notificationHandler,
                notificationSource: application,
                completionHandler: completionHandler)
    }

    // MARK: - User Activities

    public func application(_ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
            let type = userActivity.activityType
            if type == "com.rachelbrindle.rssclient.article",
                let userInfo = userActivity.userInfo,
                let feedTitle = userInfo["feed"] as? String,
                let articleID = userInfo["article"] as? String {
                    _ = self.feedRepository.feeds().then() {
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
                    _ = self.feedRepository.feeds().then {
                        guard case let Result.success(feeds) = $0 else { return }
                        guard let article = feeds.reduce(Array<Article>(), {articles, feed in
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

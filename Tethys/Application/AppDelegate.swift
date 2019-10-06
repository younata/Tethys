import UIKit
import Swinject
import TethysKit
import Result
import CoreSpotlight

@UIApplicationMain
public final class AppDelegate: UIResponder, UIApplicationDelegate {
    public var window: UIWindow?

    public lazy var container: Container = {
        let container = Container()
        TethysKit.configure(container: container)
        Tethys.configure(container: container)
        return container
    }()

    private lazy var analytics: Analytics = {
        self.container.resolve(Analytics.self)!
    }()

    private lazy var feedService: FeedService = {
        return self.container.resolve(FeedService.self)!
    }()

    private lazy var importUseCase: ImportUseCase = {
        self.container.resolve(ImportUseCase.self)!
    }()

    private func splitView() -> SplitViewController {
        self.container.resolve(SplitViewController.self)!
    }

    private func feedListController() -> FeedListController {
        return self.container.resolve(FeedListController.self)!
    }

    private func getWindow() -> UIWindow {
        if let window = self.window {
            return window
        }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        self.window = window
        return window
    }

    public func application(_ application: UIApplication,
                            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UINavigationBar.appearance().tintColor = UIColor(named: "highlight")
        UIBarButtonItem.appearance().tintColor = UIColor(named: "highlight")
        UITabBar.appearance().tintColor = UIColor(named: "highlight")

        if NSClassFromString("XCTestCase") != nil &&
            launchOptions?[UIApplication.LaunchOptionsKey(rawValue: "test")] as? Bool != true {
            self.getWindow().rootViewController = UIViewController()
            return true
        }

        self.createControllerHierarchy()

        if launchOptions == nil || launchOptions?.isEmpty == true ||
            (launchOptions?.count == 1 &&
                launchOptions?[UIApplication.LaunchOptionsKey(rawValue: "test")] as? Bool == true) {
            self.analytics.logEvent("SessionBegan", data: nil)
        }

        return true
    }

    public func application(_ app: UIApplication,
                            open url: URL,
                            options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        _ = self.importUseCase.scanForImportable(url).then { item in
            if case let .opml(url, _) = item {
                _ = self.importUseCase.importItem(url)
            }
        }
        return true
    }

    // MARK: Quick Actions

    public func application(_ application: UIApplication,
                            performActionFor shortcutItem: UIApplicationShortcutItem,
                            completionHandler: @escaping (Bool) -> Void) {
        let splitView = self.getWindow().rootViewController as? UISplitViewController
        guard let navigationController = splitView?.viewControllers.first as? UINavigationController else {
            completionHandler(false)
            return
        }
        navigationController.popToRootViewController(animated: false)

        guard let feedsViewController = navigationController.topViewController as? FeedListController else {
            completionHandler(false)
            return
        }

        if shortcutItem.type == "com.rachelbrindle.rssclient.newfeed" {
            feedsViewController.importFromWeb()
            self.analytics.logEvent("QuickActionUsed", data: ["kind": "Add New Feed"])
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }

    public func applicationWillEnterForeground(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0
    }

    // MARK: - Private

    private func createControllerHierarchy(_ feed: Feed? = nil, article: Article? = nil) {
        let feedListController = self.feedListController()
        let splitView = self.splitView()
        let detailVC = UIViewController()
        detailVC.view.backgroundColor = Theme.backgroundColor
        splitView.masterNavigationController.viewControllers = [
            feedListController
        ]
        splitView.detailNavigationController.viewControllers = [
            detailVC
        ]
        splitView.viewControllers = [
            splitView.masterNavigationController,
            splitView.detailNavigationController
        ]

        if let feed = feed {
            let articleListController = feedListController.showFeed(feed, animated: false)
            if let article = article {
                _ = articleListController.showArticle(article, animated: false)
            }
        }

        self.getWindow().rootViewController = splitView
    }
}

import UIKit
import Ra
import rNewsKit
import CoreSpotlight

extension UIApplication: DataSubscriber {
    public func markedArticle(article: Article, asRead read: Bool) {
        let incrementBy = read ? -1 : 1
        self.applicationIconBadgeNumber += incrementBy
    }

    public func deletedArticle(article: Article) {
        if (!article.read) {
            self.applicationIconBadgeNumber -= 1
        }
    }

    public func deletedFeed(feed: Feed, feedsLeft: Int) {
        if feedsLeft == 0 {
            self.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
        }
    }

    public func willUpdateFeeds() {
        self.networkActivityIndicatorVisible = true
    }

    public func didUpdateFeedsProgress(finished: Int, total: Int) {}

    public func didUpdateFeeds(feeds: [Feed]) {
        self.networkActivityIndicatorVisible = false
        let unreadCount = feeds.reduce(0) { $0 + $1.unreadArticles().count }
        self.applicationIconBadgeNumber = unreadCount
    }
}

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

    private lazy var dataRetriever: DataRetriever? = {
        return self.anInjector.create(DataRetriever.self) as? DataRetriever
    }()

    private lazy var notificationHandler: NotificationHandler? = {
        self.anInjector.create(NotificationHandler.self) as? NotificationHandler
    }()

    private lazy var backgroundFetchHandler: BackgroundFetchHandler? = {
        self.anInjector.create(BackgroundFetchHandler.self) as? BackgroundFetchHandler
    }()

    internal lazy var splitView: SplitViewController = {
        let splitView = self.anInjector.create(SplitViewController.self) as! SplitViewController
        self.anInjector.bind(SplitViewController.self, to: splitView)
        return splitView
    }()

    public func application(application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
            UINavigationBar.appearance().tintColor = UIColor.darkGreenColor()
            UIBarButtonItem.appearance().tintColor = UIColor.darkGreenColor()
            UITabBar.appearance().tintColor = UIColor.darkGreenColor()

            if NSClassFromString("XCTestCase") != nil && launchOptions?["test"] as? Bool != true {
                self.window?.rootViewController = UIViewController()
                return true
            }

            self.createControllerHierarchy()

            if let dataWriter = self.anInjector.create(DataWriter.self) as? DataWriter {
                dataWriter.addSubscriber(application)
            }

            self.notificationHandler?.enableNotifications(application)

            self.dataRetriever?.feeds {feeds in
                if feeds.isEmpty {
                    application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
                } else {
                    application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
                }
            }

            return true
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
                self.backgroundFetchHandler?.performFetch(noteHandler, notificationSource: application, completionHandler: completionHandler)
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
                    self.dataRetriever?.feeds {feeds in
                        if let feed = feeds.filter({ return $0.title == feedTitle }).first,
                            let article = feed.articles.filter({ $0.articleID?.URIRepresentation().absoluteString == articleID }).first {
                                self.createControllerHierarchy(feed, article: article)
                        }
                    }
                    return true
            }
            if #available(iOS 9.0, *) {
                if type == CSSearchableItemActionType,
                    let uniqueID = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        self.dataRetriever?.feeds {feeds in
                            guard let article = feeds.reduce(Array<Article>(), combine: {articles, feed in
                                return articles + feed.articles
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
        let master: UINavigationController

        if let masterNC = self.splitView.viewControllers.first as? UINavigationController,
            let feedsController = masterNC.viewControllers.first as? FeedsTableViewController
            where self.window?.rootViewController == self.splitView {
                master = masterNC
                feeds = feedsController
        } else {
            feeds = self.anInjector.create(FeedsTableViewController.self) as! FeedsTableViewController
            master = UINavigationController(rootViewController: feeds)
        }

        if let feedToShow = feed, let articleToShow = article {
            self.splitView.viewControllers = [master]
            let al = feeds.showFeeds([feedToShow], animated: false)
            al.showArticle(articleToShow, animated: false)
        } else {
            let detail = UINavigationController(rootViewController: ArticleViewController())
            self.splitView.viewControllers = [master, detail]
        }

        self.window?.rootViewController = splitView
    }
}


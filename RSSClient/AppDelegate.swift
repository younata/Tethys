import UIKit
import Ra

@UIApplicationMain
public class AppDelegate: UIResponder, UIApplicationDelegate {

    public lazy var window: UIWindow? = {
        let window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window.backgroundColor = UIColor.whiteColor()
        window.makeKeyAndVisible()
        return window
    }()

    private lazy var injectorModule: InjectorModule = InjectorModule()

    lazy var anInjector: Ra.Injector = {
        return Ra.Injector(module: self.injectorModule)
    }()

    lazy var dataManager: DataManager = { return self.anInjector.create(DataManager.self) as! DataManager }()

    lazy var notificationHandler: NotificationHandler = { self.anInjector.create(NotificationHandler.self) as! NotificationHandler }()

    lazy var splitDelegate: SplitDelegate = {
        let splitDelegate = SplitDelegate(splitViewController: self.splitView)
        self.anInjector.bind(SplitDelegate.self, to: splitDelegate)
        return splitDelegate
    }()

    private lazy var splitView: UISplitViewController = UISplitViewController()

    public func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
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

        notificationHandler.enableNotifications(application)

        if dataManager.feeds().count > 0 {
            application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        } else {
            application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
        }

        return true
    }

    public func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        if let window = self.window {
            notificationHandler.handleLocalNotification(notification, window: window)
        }
    }

    public func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        if let window = self.window {
            notificationHandler.handleAction(identifier, notification: notification, window: window, completionHandler: completionHandler)
        }
    }

    public func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
//        let originalList: [NSManagedObjectID?] = (dataManager.feeds().reduce([], combine: {return $0 + ($1.allArticles())}) as [Article]).map { $0.articleID }
//        if originalList.count == 0 {
//            completionHandler(.Failed)
//            return
//        }
//        dataManager.updateFeedsInBackground({(error: NSError?) in
//            if (error != nil) {
//                completionHandler(.Failed)
//                return
//            }
//            let al : [NSManagedObjectID?] = (self.dataManager.feeds().reduce([], combine: {return $0 + ($1.allArticles())}) as [Article]).map { return $0.articleID }
//            if (al.count == originalList.count) {
//                completionHandler(.NoData)
//                return
//            }
//            let alist: [NSManagedObjectID?] = al.filter({
//                return !contains(originalList, $0)
//            })
//            
//            let settings = application.currentUserNotificationSettings()
//            if settings.types & UIUserNotificationType.Alert == .Alert {
//                let articles = DataUtility.articlesWithPredicate(NSPredicate(format: "self IN %@", alist), managedObjectContext: self.dataManager.managedObjectContext)
//                for article in articles {
//                    self.notificationHandler.sendLocalNotification(application, article: article)
//                }
//            }
//            if (alist.count > 0) {
//                completionHandler(.NewData)
//            } else {
//                completionHandler(.NoData)
//            }
//        })
    }

    public func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]!) -> Void) -> Bool {
        var handled = false

        let type = userActivity.activityType
        if type == "com.rachelbrindle.rssclient.article",
            let splitView = self.window?.rootViewController as? UISplitViewController,
            let nc = splitView.viewControllers.first as? UINavigationController,
            let ftvc = nc.viewControllers.first as? FeedsTableViewController,
            let userInfo = userActivity.userInfo {
                nc.popToRootViewControllerAnimated(false)
//                let feedTitle = userInfo["feed"] as! String
//                let feed : Feed = dataManager.feeds().filter{ return $0.title == feedTitle; }.first!
//                let articleID = userInfo["article"] as! NSURL
//                let article : Article = feed.articles.filter({ return $0.objectID.URIRepresentation() == articleID }).first!
//                let al = ftvc.showFeeds([feed], animated: false)
                var controllers : [AnyObject] = []
//                controllers = [al.showArticle(article)]
                restorationHandler(controllers)
                handled = true
        }
        return handled
    }

    public func applicationDidEnterBackground(application: UIApplication) {
//        dataManager.backgroundObjectContext.save(nil)
    }

    public func applicationWillTerminate(application: UIApplication) {
//        dataManager.backgroundObjectContext.save(nil)
    }
}


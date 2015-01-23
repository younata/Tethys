//
//  AppDelegate.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
public class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    public var window: UIWindow?

    public var collapseDetailViewController = true
    
    let dataManager : DataManager = DataManager()

    public func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        self.window?.backgroundColor = UIColor.whiteColor()
        self.window?.makeKeyAndVisible()
        
        UINavigationBar.appearance().tintColor = UIColor.darkGreenColor()
        UIBarButtonItem.appearance().tintColor = UIColor.darkGreenColor()
        UITabBar.appearance().tintColor = UIColor.darkGreenColor()
        
        let feeds = FeedsTableViewController()
        feeds.dataManager = dataManager
        let master = UINavigationController(rootViewController: feeds)
        let detail = UINavigationController(rootViewController: ArticleViewController())
        
        for nc in [master, detail] {
            nc.navigationBar.translucent = true
        }
        
        let splitView = UISplitViewController()
        splitView.delegate = self
        splitView.viewControllers = [master, detail]
        self.window?.rootViewController = splitView
        splitView.delegate = self
        
        let markReadAction = UIMutableUserNotificationAction()
        markReadAction.identifier = "read"
        markReadAction.title = NSLocalizedString("Mark Read", comment: "")
        markReadAction.activationMode = .Background
        markReadAction.authenticationRequired = false
        
        let category = UIMutableUserNotificationCategory()
        category.identifier = "default"
        category.setActions([markReadAction], forContext: .Minimal)
        category.setActions([markReadAction], forContext: .Default)
        
        application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: UIUserNotificationType.Badge | UIUserNotificationType.Alert | .Sound, categories: NSSet(object: category)))
        
        if dataManager.feeds().count > 0 {
            application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        } else {
            application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
        }
        
        return true
    }
    
    public func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController: UIViewController!, ontoPrimaryViewController primaryViewController: UIViewController!) -> Bool {
        return collapseDetailViewController
    }
    
    public func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        let str = application.applicationState == .Active ? "Active" : application.applicationState == .Inactive ? "Inactive" : "Background"
        if let splitView = self.window?.rootViewController as? UISplitViewController {
            if let nc = splitView.viewControllers.first as? UINavigationController {
                if let ftvc = nc.viewControllers.first as? FeedsTableViewController {
                    if let userInfo = notification.userInfo {
                        nc.popToRootViewControllerAnimated(false)
                        let feedTitle = (userInfo["feed"] as String)
                        let feed : Feed = dataManager.feeds().filter{ return $0.title == feedTitle; }.first!
                        let articleID = (userInfo["article"] as NSURL)
                        let article : Article = (feed.articles.allObjects as [Article]).filter({ return $0.objectID.URIRepresentation() == articleID }).first!
                        let al = ftvc.showFeeds([feed], animated: false)
                        al.showArticle(article)
                        return
                    }
                }
            }
        }
    }
    
    public func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        if let userInfo = notification.userInfo {
            let feedTitle = (userInfo["feed"] as String)
            let feed : Feed = dataManager.feeds().filter{ return $0.title == feedTitle; }.first!
            let articleID = (userInfo["article"] as NSURL)
            let article : Article = (feed.articles.allObjects as [Article]).filter({ return $0.objectID.URIRepresentation() == articleID }).first!
            if identifier == "read" {
                dataManager.readArticle(article)
            } else if identifier == "view" {
                let nc = (self.window!.rootViewController! as UINavigationController)
                let ftvc = (nc.viewControllers.first! as FeedsTableViewController)
                nc.popToRootViewControllerAnimated(false)
                let al = ftvc.showFeeds([feed], animated: false)
                al.showArticle(article)
            }
        }
    }
    
    public func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        let originalList: [NSManagedObjectID] = (dataManager.feeds().reduce([], combine: {return $0 + ($1.articles.allObjects as [Article])}) as [Article]).map { return $0.objectID }
        if originalList.count == 0 {
            completionHandler(.Failed)
            return
        }
        dataManager.updateFeedsInBackground({(error: NSError?) in
            if (error != nil) {
                completionHandler(.Failed)
                return
            }
            let al : [NSManagedObjectID] = (self.dataManager.feeds().reduce([], combine: {return $0 + ($1.articles.allObjects as [Article])}) as [Article]).map { return $0.objectID }
            if (al.count == originalList.count) {
                completionHandler(.NoData)
                return
            }
            let alist: [NSManagedObjectID] = al.filter({
                return !contains(originalList, $0)
            })
            
            let settings = application.currentUserNotificationSettings()
            if settings.types & UIUserNotificationType.Alert == .Alert {
                let articles : [Article] = self.dataManager.entities("Article", matchingPredicate: NSPredicate(format: "self IN %@", alist)!) as [Article]
                for article: Article in articles {
                    // show local notification.
                    let note = UILocalNotification()
                    note.alertBody = NSString.localizedStringWithFormat("New article in %@: %@", article.feed.feedTitle() ?? "", article.title)
                    let dict = ["feed": article.feed.title, "article": article.objectID.URIRepresentation()]
                    note.userInfo = dict
                    note.fireDate = NSDate()
                    note.category = "default"
                    application.presentLocalNotificationNow(note)
                }
            }
            if (alist.count > 0) {
                completionHandler(.NewData)
            } else {
                completionHandler(.NoData)
            }
        })
    }
    
    public func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]!) -> Void) -> Bool {
        var handled = false
        
        let type = userActivity.activityType
        if type == "com.rachelbrindle.rssclient.article" {
            var controllers : [AnyObject] = []
            if let splitView = self.window?.rootViewController as? UISplitViewController {
                if let nc = splitView.viewControllers.first as? UINavigationController {
                    if let ftvc = nc.viewControllers.first as? FeedsTableViewController {
                        if let userInfo = userActivity.userInfo {
                            nc.popToRootViewControllerAnimated(false)
                            let feedTitle = (userInfo["feed"] as String)
                            let feed : Feed = dataManager.feeds().filter{ return $0.title == feedTitle; }.first!
                            let articleID = (userInfo["article"] as NSURL)
                            let article : Article = (feed.articles.allObjects as [Article]).filter({ return $0.objectID.URIRepresentation() == articleID }).first!
                            let al = ftvc.showFeeds([feed], animated: false)
                            controllers = [al.showArticle(article)]
                            restorationHandler(controllers)
                            handled = true
                        }
                    }
                }
            }
        }
        return handled
    }

    public func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    public func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        dataManager.managedObjectContext.save(nil)
    }

    public func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    public func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    public func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        dataManager.managedObjectContext.save(nil)
    }

    // MARK: - Core Data stack
    /*

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.rachelbrindle.RSSClient" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] as NSURL
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("RSSClient", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("RSSClient.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        if coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil, error: &error) == nil {
            coordinator = nil
            // Report any error we got.
            let dict = NSMutableDictionary()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(error), \(error!.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        if let moc = self.managedObjectContext {
            var error: NSError? = nil
            if moc.hasChanges && !moc.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                NSLog("Unresolved error \(error), \(error!.userInfo)")
                abort()
            }
        }
    }*/

}


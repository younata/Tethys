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
public class AppDelegate: UIResponder, UIApplicationDelegate {

    public lazy var window: UIWindow = {
        let window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window.backgroundColor = UIColor.whiteColor()
        window.makeKeyAndVisible()
        return window
    }()
    
    lazy var dataManager = DataManager()
    
    lazy var notificationHandler : NotificationHandler = {
        return NotificationHandler(dataManager: self.dataManager)
    }()
    
    lazy var splitDelegate : SplitDelegate = {
        return SplitDelegate(splitViewController: (self.window.rootViewController as UISplitViewController))
    }()

    public func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
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
        self.window.rootViewController = splitView
        splitView.delegate = splitDelegate
        splitView.viewControllers = [master, detail]
        
        notificationHandler.enableNotifications(application)
        
        if dataManager.feeds().count > 0 {
            application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        } else {
            application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
        }
        
        return true
    }
    
    public func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
        notificationHandler.handleLocalNotification(application, notification: notification, window: self.window)
    }
    
    public func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forLocalNotification notification: UILocalNotification, completionHandler: () -> Void) {
        notificationHandler.handleAction(application, identifier: identifier, notification: notification, window: self.window, completionHandler: completionHandler)
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
                    self.notificationHandler.sendLocalNotification(application, article: article)
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
            if let splitView = self.window.rootViewController as? UISplitViewController {
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

    public func applicationDidEnterBackground(application: UIApplication) {
        dataManager.managedObjectContext.save(nil)
    }
    
    public func applicationWillTerminate(application: UIApplication) {
        dataManager.managedObjectContext.save(nil)
    }
}


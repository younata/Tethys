//
//  NotificationHandler.swift
//  RSSClient
//
//  Created by Rachel Brindle on 1/24/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import UIKit

class NotificationHandler {
    let dataManager: DataManager
    
    func enableNotifications(application: UIApplication) {
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
    }
    
    func handleLocalNotification(application: UIApplication, notification: UILocalNotification, window: UIWindow) {
        let str = application.applicationState == .Active ? "Active" : application.applicationState == .Inactive ? "Inactive" : "Background"
        
        if let userInfo = notification.userInfo {
            let (feed, article) = feedAndArticleFromUserInfo(userInfo)
            showFeed(feed, article: article, window: window)
        }
    }
    
    func handleAction(application: UIApplication, identifier: String?, notification: UILocalNotification, window: UIWindow, completionHandler: () -> Void) {
        if let userInfo = notification.userInfo {
            let (feed, article) = feedAndArticleFromUserInfo(userInfo)
            if identifier == "read" {
                dataManager.readArticle(article)
            } else if identifier == "view" {
                showFeed(feed, article: article, window: window)
            }
        }
    }
    
    func sendLocalNotification(application: UIApplication, article: Article) {
        let note = UILocalNotification()
        note.alertBody = NSString.localizedStringWithFormat("New article in %@: %@", article.feed.feedTitle() ?? "", article.title)
        let dict = ["feed": article.feed.objectID.URIRepresentation().absoluteString!, "article": article.objectID.URIRepresentation().absoluteString!]
        note.userInfo = dict
        note.fireDate = NSDate()
        note.category = "default"
        application.presentLocalNotificationNow(note)
    }
    
    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }
    
    private func feedAndArticleFromUserInfo(userInfo: [NSObject : AnyObject]) -> (Feed, Article) {
        let feedID = (userInfo["feed"] as String)
        let feed : Feed = dataManager.feeds().filter{ return $0.objectID.URIRepresentation().absoluteString == feedID; }.first!
        let articleID = (userInfo["article"] as String)
        let article : Article = feed.allArticles(dataManager).filter({ return $0.objectID.URIRepresentation().absoluteString == articleID }).first!
        return (feed, article)
    }
    
    private func showFeed(feed: Feed, article: Article, window: UIWindow) {
        if let nc = (window.rootViewController as? UISplitViewController)?.viewControllers.first as? UINavigationController {
            if let ftvc = nc.viewControllers.first as? FeedsTableViewController {
                nc.popToRootViewControllerAnimated(false)
                let al = ftvc.showFeeds([feed], animated: false)
                al.showArticle(article)
            }
        }
    }
}
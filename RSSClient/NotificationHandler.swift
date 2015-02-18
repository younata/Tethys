//
//  NotificationHandler.swift
//  RSSClient
//
//  Created by Rachel Brindle on 1/24/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import UIKit

class NotificationHandler {
    
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
        
        application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Badge | .Alert | .Sound, categories: NSSet(object: category)))
    }
    
    func handleLocalNotification(notification: UILocalNotification, window: UIWindow, dataManager: DataManager) {
        if let userInfo = notification.userInfo {
            let (feed, article) = feedAndArticleFromUserInfo(userInfo, dataManager: dataManager)
            showArticle(article, window: window)
        }
    }
    
    func handleAction(identifier: String?, notification: UILocalNotification, window: UIWindow, dataManager: DataManager, completionHandler: () -> Void) {
        if let userInfo = notification.userInfo {
            let (feed, article) = feedAndArticleFromUserInfo(userInfo, dataManager: dataManager)
            if identifier == "read" {
//                dataManager.readArticle(article)
            } else if identifier == "view" {
                showArticle(article, window: window)
            }
        }
    }
    
    func sendLocalNotification(application: UIApplication, article: Article) {
        let note = UILocalNotification()
        note.alertBody = NSString.localizedStringWithFormat("New article in %@: %@", article.feed?.feedTitle() ?? "", article.title)

        let feedID = article.feed!.objectID.URIRepresentation().absoluteString!
        let articleID = article.objectID.URIRepresentation().absoluteString!

        let dict = ["feed": feedID, "article": articleID]
        note.userInfo = dict
        note.fireDate = NSDate()
        note.category = "default"
        let existingNotes = application.scheduledLocalNotifications as [UILocalNotification]

        application.scheduledLocalNotifications = existingNotes + [note]
//        application.presentLocalNotificationNow(note)
    }
    
    private func feedAndArticleFromUserInfo(userInfo: [NSObject : AnyObject], dataManager: DataManager) -> (Feed, Article) {
        let feedID = (userInfo["feed"] as String)
        let feed : Feed = dataManager.feeds().filter{ return $0.objectID.URIRepresentation().absoluteString == feedID; }.first!
        let articleID = (userInfo["article"] as String)
        let article : Article = feed.allArticles(dataManager).filter({ return $0.objectID.URIRepresentation().absoluteString == articleID }).first!
        return (feed, article)
    }
    
    private func showArticle(article: Article, window: UIWindow) {
        if let nc = (window.rootViewController as? UISplitViewController)?.viewControllers.first as? UINavigationController {
            if let ftvc = nc.viewControllers.first as? FeedsTableViewController {
                nc.popToRootViewControllerAnimated(false)
                let feed = article.feed
//                let al = ftvc.showFeeds([feed], animated: false)
//                al.showArticle(article)
            }
        }
    }
}
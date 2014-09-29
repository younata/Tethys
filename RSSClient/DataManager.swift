//
//  DataManager.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation
import CoreData

private let instance = DataManager()

class DataManager: NSObject, MWFeedParserDelegate {
    class func sharedInstance() -> DataManager {
        return instance
    }
    
    func feeds() -> [Feed] {
        return (entities("Feed", matchingPredicate: NSPredicate(value: true)) as [Feed])
    }
    
    func newFeed(feedURL: String, withICO icoURL: String?) -> Feed {
        let predicate = NSPredicate(format: "url = %@", feedURL)
        var feed: Feed! = nil
        if let theFeed = entities("Feed", matchingPredicate: predicate).last as? Feed {
            feed = theFeed
        } else {
            feed = (NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: managedObjectContext) as Feed)
            feed.url = feedURL
            self.managedObjectContext.save(nil)
            if let ico = icoURL {
                let manager = AFHTTPRequestOperationManager()
                manager.GET(ico, parameters: [:], success: {(op: AFHTTPRequestOperation!, response: AnyObject!) in
                    println("\(response)")
                    if (response.isKindOfClass(UIImage.self)) {
                        feed.image = (response as UIImage)
                        self.managedObjectContext.save(nil)
                        NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
                    }
                }, failure: {(op: AFHTTPRequestOperation!, response: AnyObject!) in
                    NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
                })
            } else {
                NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
            }
        }
        self.loadFeed(feedURL)
        return feed
    }
    
    func deleteFeed(feed: Feed) {
        for article in (feed.articles.allObjects as [Article]) {
            self.managedObjectContext.deleteObject(article)
        }
        self.managedObjectContext.deleteObject(feed)
        self.managedObjectContext.save(nil)
    }
    
    func updateFeeds() {
        for feed in feeds() {
            loadFeed(feed.url)
        }
    }
    
    func loadFeed(url: NSString) {
        let parser = MWFeedParser(feedURL: NSURL(string: url))
        parser.feedParseType = ParseTypeFull
        parser.connectionType = ConnectionTypeAsynchronously
        parser.delegate = self
        parser.parse()
    }
    
    // MARK: MWFeedParserDelegate
    
    func feedParser(parser: MWFeedParser!, didParseFeedInfo info: MWFeedInfo!) {
        let predicate = NSPredicate(format: "url = %@", parser.url().absoluteString!)
        if let feed = entities("Feed", matchingPredicate: predicate).last as? Feed {
            feed.title = info.title
            feed.summary = info.summary
            // TODO: feed.image
            // do something info.link?
        } else {
            let feed = (NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: managedObjectContext) as Feed)
            feed.title = info.title
            feed.summary = info.summary
            feed.url = parser.url().absoluteString!
            // create?
        }
        managedObjectContext.save(nil)
    }
    
    func feedParser(parser: MWFeedParser!, didParseFeedItem item: MWFeedItem!) {
        let predicate = NSPredicate(format: "link = %@", item.link)
        if let article = entities("Article", matchingPredicate: predicate).last as? Article {
            article.title = item.title
            article.link = item.link
            article.updatedAt = item.updated
            article.summary = item.summary
            article.content = item.content
            article.author = item.author
            if (article.enclosureURLs.description != item.enclosures.description) {
                // TODO: enclosures
            }
        } else {
            // create
            if let feed = entities("Feed", matchingPredicate: NSPredicate(format: "url = %@", parser.url().absoluteString!)).last as? Feed {
                let article = (NSEntityDescription.insertNewObjectForEntityForName("Article", inManagedObjectContext: managedObjectContext) as Article)
                article.title = item.title
                article.link = item.link
                article.published = item.date ?? NSDate()
                article.updatedAt = item.updated
                article.summary = item.summary
                article.content = item.content
                article.author = item.author
                article.enclosureURLs = item.enclosures
                article.feed = feed
                article.read = false
                feed.addArticlesObject(article)
                // TODO: enclosures
            } else {
                println("Error, unable to find feed for item.")
            }
        }
        managedObjectContext.save(nil)
    }
    
    func feedParserDidFinish(parser: MWFeedParser!) {
        NSNotificationCenter.defaultCenter().postNotificationName("FeedParserFinished", object: parser.url().absoluteString!)
    }
    
    // MARK: Generic Core Data
    
    func entities(entity: String, matchingPredicate predicate: NSPredicate) -> [AnyObject] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName(entity, inManagedObjectContext: managedObjectContext)
        request.predicate = predicate
        
        var error : NSError? = nil
        var ret = managedObjectContext.executeFetchRequest(request, error: &error)
        if (ret == nil) {
            println("Error executing fetch request: \(error)")
            return []
        }
        return ret!
    }
    
    func saveContext() {
        var error: NSError? = nil
        if (managedObjectContext.hasChanges && !managedObjectContext.save(&error)) {
            println("Error saving context: \(error)")
            fatalError("Error saving context")
        }
    }
    
    let managedObjectModel: NSManagedObjectModel
    let persistentStoreCoordinator: NSPersistentStoreCoordinator
    let managedObjectContext: NSManagedObjectContext
    
    override init() {
        managedObjectModel = NSManagedObjectModel.mergedModelFromBundles(nil)
        let applicationDocumentsDirectory: String = (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).last as String)
        let storeURL = NSURL.fileURLWithPath(applicationDocumentsDirectory.stringByAppendingPathComponent("RSSClient.sqlite"))
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        var error: NSError? = nil
        persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: nil, error: &error)
        
        managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        super.init()
    }
}
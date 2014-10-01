//
//  DataManager.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Foundation
import CoreData
import WebKit

private let instance = DataManager()

class DataManager: NSObject, MWFeedParserDelegate {
    class func sharedInstance() -> DataManager {
        return instance
    }
    
    func feeds() -> [Feed] {
        return (entities("Feed", matchingPredicate: NSPredicate(value: true), sortDescriptors: [NSSortDescriptor(key: "title", ascending: true)]) as [Feed]).sorted { return $0.title < $1.title }
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
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
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
    
    private var comp: (Void)->(Void) = {}
    private var feedsLeft = 0
    
    func updateFeeds(completion: (Void)->(Void)) {
        updateFeeds(feeds(), completion: completion)
    }
    
    func updateFeeds(feeds: [Feed], completion: (Void)->(Void)) {
        feedsLeft += feeds.count
        comp = completion
        for feed in feeds {
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
    
    let contentRenderer = WKWebView(frame: CGRectZero)
    
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
            if let link = info.link {
                AFHTTPRequestOperationManager().GET(link, parameters: [:], success: {(_, response: AnyObject!) in
                    self.contentRenderer.loadHTMLString((response as String), baseURL: NSURL(string: link))
                    let ICOScript = NSString.stringWithContentsOfFile(NSBundle.mainBundle().pathForResource("FindICO", ofType: "js")!, encoding: NSUTF8StringEncoding, error: nil)
                    self.contentRenderer.evaluateJavaScript(ICOScript, completionHandler: {(jsResponse: AnyObject!, error: NSError?) in
                        if (error == nil) {
                            if let imageLink = jsResponse as? String {
                                AFHTTPRequestOperationManager().GET(imageLink, parameters: [:], success: {(_, image: AnyObject!) in
                                    if let im = image as? UIImage {
                                        feed.image = im
                                        self.managedObjectContext.save(nil)
                                        NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
                                    }
                                }, failure:{(_, error: NSError!) in })
                            }
                        }
                    })
                    
                }, failure: {(_, error: NSError!) in })
            }
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
            if (article.enclosureURLs?.description != item.enclosures?.description) {
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
    
    func feedParser(parser: MWFeedParser!, didFailWithError error: NSError!) {
        feedsLeft -= 1
        if (feedsLeft == 0) {
            self.comp()
        }
    }
    
    func feedParserDidFinish(parser: MWFeedParser!) {
        NSNotificationCenter.defaultCenter().postNotificationName("FeedParserFinished", object: parser.url().absoluteString!)
        feedsLeft -= 1
        if (feedsLeft == 0) {
            self.comp()
        }
    }
    
    // MARK: Generic Core Data
    
    func entities(entity: String, matchingPredicate predicate: NSPredicate, sortDescriptors: [NSSortDescriptor] = []) -> [AnyObject] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName(entity, inManagedObjectContext: managedObjectContext)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
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
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
import Alamofire

private let instance = DataManager()

class DataManager: NSObject, MWFeedParserDelegate {
    class func sharedInstance() -> DataManager {
        return instance
    }
    
    // MARK: - Groups
    
    func groups() -> [Group] {
        return (entities("Group", matchingPredicate: NSPredicate(value: true)) as [Group]).sorted { return $0.name < $1.name; }
    }
    
    func newGroup(name: String) -> Group {
        if let group = entities("Group", matchingPredicate: NSPredicate(format: "name = %@", name)!).last as? Group {
            return group
        } else {
            let group = (NSEntityDescription.insertNewObjectForEntityForName("Group", inManagedObjectContext: managedObjectContext) as Group)
            group.name = name
            managedObjectContext.save(nil)
            return group
        }
    }
    
    func addFeed(feed: Feed, toGroup group:Group) {
        group.addFeedsObject(feed)
        feed.addGroupsObject(group)
    }
    
    func deleteGroup(group: Group) {
        for feed: Feed in (group.feeds.allObjects as [Feed]) {
            group.removeFeedsObject(feed)
            feed.removeGroupsObject(group)
        }
        self.managedObjectContext.deleteObject(group)
        self.managedObjectContext.save(nil)
    }
    
    // MARK: - Feeds
    
    func feeds() -> [Feed] {
        return (entities("Feed", matchingPredicate: NSPredicate(value: true)) as [Feed]).sorted {
            if $0.title == nil {
                return true
            } else if $1.title == nil {
                return false
            }
            return $0.title < $1.title
        }
    }
    
    func newFeed(feedURL: String) -> Feed {
        return newFeed(feedURL, completion: {(_) in })
    }
    
    func newFeed(feedURL: String, completion: (NSError?) -> (Void)) -> Feed {
        let predicate = NSPredicate(format: "url = %@", feedURL)
        var feed: Feed! = nil
        if let theFeed = entities("Feed", matchingPredicate: predicate!).last as? Feed {
            feed = theFeed
        } else {
            feed = (NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: managedObjectContext) as Feed)
            feed.url = feedURL
            self.managedObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        self.updateFeeds([feed], completion: completion)
        return feed
    }
    
    func deleteFeed(feed: Feed) {
        for article in (feed.articles.allObjects as [Article]) {
            self.managedObjectContext.deleteObject(article)
        }
        for group: Group in (feed.groups.allObjects as [Group]) {
            group.removeFeedsObject(feed)
            feed.removeGroupsObject(group)
        }
        self.managedObjectContext.deleteObject(feed)
        self.managedObjectContext.save(nil)
        if (feeds().count == 0) {
            UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
        }
    }
    
    private var comp: (NSError?)->(Void) = {(error: NSError?) in }
    private var feedsLeft = 0
    
    func updateFeeds(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion)
    }
    
    func updateFeeds(feeds: [Feed], completion: (NSError?)->(Void)) {
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
    
    // MARK: - MWFeedParserDelegate
    
    private let contentRenderer = WKWebView(frame: CGRectZero)
    
    func feedParser(parser: MWFeedParser!, didParseFeedInfo info: MWFeedInfo!) {
        let predicate = NSPredicate(format: "url = %@", parser.url().absoluteString!)!
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
            /*
            if let link = info.link {
                Alamofire.request(.GET, link).response {(_, _, response, error) in
                    self.contentRenderer.loadHTMLString((response as String), baseURL: NSURL(string: link))
                    let ICOScript = NSString(contentsOfFile: NSBundle.mainBundle().pathForResource("FindICO", ofType: "js")!, encoding: NSUTF8StringEncoding, error: nil)!
                    self.contentRenderer.evaluateJavaScript(ICOScript, completionHandler: {(jsResponse: AnyObject!, error: NSError?) in
                        if (error == nil) {
                            if let imageLink = jsResponse as? String {
                                
                                Alamofire.request(.GET, imageLink).response {(_, _, image, error) in
                                    if let im = image as? UIImage {
                                        feed.image = im
                                        self.managedObjectContext.save(nil)
                                        NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
                                    }
                                }
                            }
                        }
                    })
                }
            }
            */
            // create?
        }
        managedObjectContext.save(nil)
    }
    
    func feedParser(parser: MWFeedParser!, didParseFeedItem item: MWFeedItem!) {
        let predicate = NSPredicate(format: "link = %@", item.link)!
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
            if let feed = entities("Feed", matchingPredicate: NSPredicate(format: "url = %@", parser.url().absoluteString!)!).last as? Feed {
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
                
                var cnt = article.summary ?? article.content ?? ""
                
                let data = cnt.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
                let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
                
                article.preview = NSAttributedString(data: data, options: options, documentAttributes: nil, error: nil)!.string
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
            self.comp(error)
        }
    }
    
    func feedParserDidFinish(parser: MWFeedParser!) {
        NSNotificationCenter.defaultCenter().postNotificationName("FeedParserFinished", object: parser.url().absoluteString!)
        feedsLeft -= 1
        managedObjectContext.save(nil)
        if (feedsLeft == 0) {
            self.comp(nil)
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
        if managedObjectContext.hasChanges {
            managedObjectContext.save(&error)
            if let err = error {
                println("Error saving context: \(error)")
            }
        }
    }
    
    let managedObjectModel: NSManagedObjectModel
    let persistentStoreCoordinator: NSPersistentStoreCoordinator
    let managedObjectContext: NSManagedObjectContext
    
    override init() {
        var unitTesting = false
        if let modelURL = NSBundle.mainBundle().URLForResource("RSSClient", withExtension: "momd") {
            managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL)!
        } else {
            managedObjectModel = NSManagedObjectModel.mergedModelFromBundles(NSBundle.allBundles())!
            unitTesting = true
        }
        let applicationDocumentsDirectory: String = (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).last as String)
        let storeURL = NSURL.fileURLWithPath(applicationDocumentsDirectory.stringByAppendingPathComponent("RSSClient.sqlite"))
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        var error: NSError? = nil
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        if unitTesting {
            persistentStoreCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: &error)
        } else {
            persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: managedObjectModel.configurations.last as NSString?, URL: storeURL, options: options, error: &error)
        }
        if (error != nil) {
            //println("Error adding persistent data store: \(error!)")
            NSFileManager.defaultManager().removeItemAtURL(storeURL!, error: nil)
            error = nil
            persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: managedObjectModel.configurations.last as NSString?, URL: storeURL, options: options, error: &error)
            if (error != nil) {
                println("Fatal error adding persistent data store: \(error!)")
                fatalError("")
            }
        }
        
        managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        super.init()
    }
}
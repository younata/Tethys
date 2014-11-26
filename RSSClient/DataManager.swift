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

class DataManager: NSObject {
    
    // MARK: OPML
    
    func importOPML(opml: NSURL) {
        importOPML(opml, progress: {(_) in }, completion: {(_) in })
    }
    
    func importOPML(opml: NSURL, progress: (Double) -> Void, completion: ([Feed]) -> Void) {
        if let text = NSString(contentsOfURL: opml, encoding: NSUTF8StringEncoding, error: nil) {
            let opmlParser = OPMLParser(text: text)
            opmlParser.callback = {(feeds) in
                var ret : [Feed] = []
                if feeds.count == 0 {
                    completion([])
                }
                var i = 0
                for feed in feeds {
                    dispatch_async(dispatch_get_main_queue()) {
                        ret.append(self.newFeed(feed) {(error) in
                            if let err = error {
                                println("error importing \(feed): \(err)")
                            }
                            println("imported \(feed)")
                            i++
                            progress(Double(i) / Double(feeds.count))
                            if i == feeds.count {
                                completion(ret)
                            }
                        })
                    }
                }
            }
            opmlParser.parse()
        }
    }
    
    func generateOPMLContents(feeds: [Feed]) -> String {
        var ret = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><opml version=\"2.0\"><body>"
        for feed in feeds.filter({return $0.query == nil}) {
            ret += "<outline xmlURL=\"\(feed.url)\" title=\"\(feed.title)\" type=\"rss\"/>"
        }
        ret += "</body></opml>"
        return ret
    }
    
    func writeOPML() {
        self.generateOPMLContents(self.feeds()).writeToFile(NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent("rnews.opml"), atomically: true, encoding: NSUTF8StringEncoding, error: nil)
    }
    
    // MARK: Feeds
    
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
            feed = NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: managedObjectContext) as Feed
            feed.url = feedURL
            self.managedObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        #if os(iOS)
        UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        #endif
        self.updateFeeds([feed], completion: completion)
        self.writeOPML()
        return feed
    }
    
    func newQueryFeed(title: String, code: String, summary: String? = nil) -> Feed {
        let predicate = NSPredicate(format: "title = %@", title)
        var feed: Feed! = nil
        if let theFeed = entities("Feed", matchingPredicate: predicate!).last as? Feed {
            feed = theFeed
        } else {
            feed = NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: managedObjectContext) as Feed
            feed.title = title
            feed.query = code
            feed.summary = summary
            self.managedObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        return feed
    }
    
    func deleteFeed(feed: Feed) {
        for article in (feed.articles.allObjects as [Article]) {
            self.managedObjectContext.deleteObject(article)
        }
        self.managedObjectContext.deleteObject(feed)
        self.managedObjectContext.save(nil)
        if (feeds().count == 0) {
            #if os(iOS)
            UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
            #endif
        }
        self.writeOPML()
    }
    
    func updateFeeds(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion)
    }
    
    var parsers : [FeedParser] = []
    
    func updateFeeds(feeds: [Feed], completion: (NSError?)->(Void)) {
        var feedsLeft = feeds.count
        for feed in feeds.filter({$0.url != nil}) {
            let feedParser = FeedParser(URL: NSURL(string: feed.url)!)
            feedParser.success {(info, items) in
                var predicate = NSPredicate(format: "url = %@", feed.url)!
                
                var summary : String = ""
                if let s = info.summary {
                    let data = s.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
                    let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
                    summary = s
                    if let aString = NSAttributedString(data: data, options: options, documentAttributes: nil, error: nil) {
                        summary = aString.string
                    }
                }
                if let feed = self.entities("Feed", matchingPredicate: predicate).last as? Feed {
                    feed.title = info.title
                    feed.summary = summary
                } else {
                    let feed = (NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: self.managedObjectContext) as Feed)
                    feed.title = info.title
                    feed.summary = summary
                }
                for item in items {
                    predicate = NSPredicate(format: "link = %@", item.link)!
                    if let article = self.entities("Article", matchingPredicate: predicate).last as? Article {
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
                        if let feed = self.entities("Feed", matchingPredicate: NSPredicate(format: "url = %@", feed.url)!).last as? Feed {
                            let article = (NSEntityDescription.insertNewObjectForEntityForName("Article", inManagedObjectContext: self.managedObjectContext) as Article)
                            article.title = item.title
                            article.link = item.link
                            article.published = item.date ?? NSDate()
                            article.updatedAt = item.updated
                            article.summary = item.summary
                            article.content = item.content
                            article.author = item.author
                            article.feed = feed
                            article.read = false
                            
                            feed.addArticlesObject(article)
                            
                            /*
                            if let enclosures = item.enclosures {
                                article.enclosureURLs = (enclosures as [[String: AnyObject]]).map { return $0["url"] as String } as [String]
                                var toInsert : [[String: AnyObject]] = []
                                for (idx, itm) in enumerate(item.enclosures as [[String: AnyObject]]) {
                                    let url = itm["url"] as String
                                    let length = itm["length"] as Int
                                    let type = itm["type"] as String
                                    request(.GET, url).response {(_, _, response, error) in
                                        if let err = error {
                                            // TODO: notify the user!
                                        } else {
                                            if let data = response as? NSData {
                                                if data.length == length {
                                                    let ti = ["type": type, "data": data, "url": url]
                                                    toInsert.append(ti)
                                                    if idx == (item.enclosures.count - 1) {
                                                        article.enclosures = toInsert
                                                        self.managedObjectContext.save(nil)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            */
                        } else {
                            println("Error, unable to find feed for item.")
                        }
                    }
                }
                self.managedObjectContext.save(nil)
                
                feedsLeft--
                if (feedsLeft == 0) {
                    completion(nil)
                }
                self.parsers = self.parsers.filter { $0 != feedParser }
            }.failure {(error) in
                feedsLeft--
                if (feedsLeft == 0) {
                    completion(error)
                }
            }
            feedParser.parse()
            self.parsers.append(feedParser)
        }
    }
    
    // MARK: Articles
    
    func articles() -> [Article] {
        return (entities("Article", matchingPredicate: NSPredicate(value: true)) as [Article]).sorted {(a : Article, b: Article) in
            if let da = a.updatedAt ?? a.published {
                if let db = b.updatedAt ?? b.published {
                    return da.timeIntervalSince1970 > db.timeIntervalSince1970
                }
            }
            return true
        }
    }
    
    func articlesMatchingQuery(query: String) -> [Article] {
        // TODO: research javascriptcore to do this. Until then, query feeds are useless.
        return articles().filter {(article) in
            return true
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
    
    func registerForiCloudNotifications() {
        let center = NSNotificationCenter.defaultCenter()
        center.addObserver(self, selector: "storesWillChange:", name: NSPersistentStoreCoordinatorStoresWillChangeNotification, object: persistentStoreCoordinator)
        center.addObserver(self, selector: "storesDidChange:", name: NSPersistentStoreCoordinatorStoresDidChangeNotification, object: persistentStoreCoordinator)
        center.addObserver(self, selector: "storeDidImportiCloudContentChanges:", name: NSPersistentStoreDidImportUbiquitousContentChangesNotification, object: persistentStoreCoordinator)
    }
    
    func storeDidImportiCloudContentChanges(note: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: nil)
    }
    
    func storesWillChange(note: NSNotification) {
        managedObjectContext.performBlockAndWait {
            var error: NSError? = nil
            if (self.managedObjectContext.hasChanges) {
                var success = self.managedObjectContext.save(&error)
                if !success && error != nil {
                    println("Error saving store: \(error!)")
                }
            }
            self.managedObjectContext.reset()
        }
        NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: nil)
    }
    
    func storesDidChange(note: NSNotification) {
        NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: nil)
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
        var options : [String: AnyObject] = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        if NSUserDefaults.standardUserDefaults().boolForKey("use_iCloud") {
            options[NSPersistentStoreUbiquitousContentNameKey] = "RSSClient"
            //options[NSPersistentStoreRebuildFromUbiquitousContentOption] = true
        }
        if unitTesting {
            persistentStoreCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: &error)
        } else {
            persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: managedObjectModel.configurations.last as NSString?, URL: storeURL, options: options, error: &error)
        }
        if (error != nil) {
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
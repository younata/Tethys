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

class DataManager: NSObject {
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
    
    // MARK: OPML
    
    func importOPML(opml: NSURL) {
        importOPML(opml, progress: {(_) in }, completion: {(_) in })
    }
    
    func importOPML(opml: NSURL, progress: (Double) -> Void, completion: ([Feed]) -> Void) {
        if let text = NSString(contentsOfURL: opml, encoding: NSUTF8StringEncoding, error: nil) {
            let opmlParser = OPMLParser(text: text)
            opmlParser.callback = {(feeds) in
                var ret : [Feed] = []
                for feed in feeds {
                    dispatch_async(dispatch_get_main_queue()) {
                        ret.append(self.newFeed(feed) {(error) in
                            if let err = error {
                                println("error importing \(feed): \(err)")
                            }
                            println("imported \(feed)")
                            progress(Double(ret.count + 1) / Double(feeds.count))
                            if (ret.count + 1) == feeds.count {
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
        for feed in feeds {
            ret += "<outline xmlURL=\"\(feed.url)\""
        }
        ret += "</body></opml>"
        return ret
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
    
    func updateFeeds(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion)
    }
    
    var parsers : [FeedParser] = []
    
    func updateFeeds(feeds: [Feed], completion: (NSError?)->(Void)) {
        var feedsLeft = feeds.count
        for feed in feeds {
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
                            article.enclosureURLs = item.enclosures
                            article.feed = feed
                            article.read = false
                            
                            feed.addArticlesObject(article)
                            // TODO: enclosures
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
            }.failure {
                feedsLeft--
                if (feedsLeft == 0) {
                    completion($0)
                }
            }
            feedParser.parse()
            self.parsers.append(feedParser)
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
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
import JavaScriptCore

class DataManager: NSObject {
    // MARK: Feeds
    
    func newFeed(feedURL: String) -> Feed {
        return newFeed(feedURL, completion: {(_) in })
    }
    
    func newFeed(feedURL: String, completion: (NSError?) -> (Void)) -> Feed {
        let feed = feedManager.newFeed(feedURL, managedObjectContext: managedObjectContext, completion: completion)

        #if os(iOS)
        UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        #endif
        self.updateFeeds([feed], completion: completion)
        let opmlManager = self.injector!.create(OPMLManager.self) as OPMLManager
        opmlManager.writeOPML()
        return feed
    }
    
    func deleteFeed(feed: Feed) {
        feedManager.deleteFeed(feed)
        if (feedManager.feeds().count == 0) {
            #if os(iOS)
            UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
            #endif
        }
        let opmlManager = self.injector!.create(OPMLManager.self) as OPMLManager
        opmlManager.writeOPML()
    }
    
    func updateFeeds(completion: (NSError?)->(Void)) {
        updateFeeds(feedManager.feeds(), completion: completion)
    }
    
    func updateFeedsInBackground(completion: (NSError?)->(Void)) {
        updateFeeds(feedManager.feeds(), completion: completion, backgroundFetch: true)
    }
    
    var parsers : [FeedParser] = []
    
    func updateFeeds(feeds: [Feed], completion: (NSError?)->(Void), backgroundFetch: Bool = false) {
        let feedIds = feeds.filter { $0.url != nil }.map { $0.objectID }
        
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
        dispatch_async(queue) {
            let ctx = self.managedObjectContext
            let theFeeds = self.dataHelper.entities("Feed", matchingPredicate: NSPredicate(format: "self in %@", feedIds)!, managedObjectContext: ctx) as [Feed]
            self.feedManager.updateFeeds(theFeeds, completion: completion, backgroundFetch: backgroundFetch)
        }
    }
    
    func setApplicationBadgeCount() {
        let num = feedManager.feeds(managedObjectContext).filter {return !$0.isQueryFeed()}.reduce(0) {return $0 + Int($1.unreadArticles(self))}
        #if os(iOS)
            UIApplication.sharedApplication().applicationIconBadgeNumber = num
        #elseif os(OSX)
            NSApplication.sharedApplication().dockTile.badgeLabel = "\(num)"
        #endif
    }
    
    // MARK: Enclosures
    
    func allEnclosures() -> [Enclosure] {
        return (dataHelper.entities("Enclosure", matchingPredicate: NSPredicate(value: true), managedObjectContext: managedObjectContext)! as [Enclosure]).sorted {(a : Enclosure, b: Enclosure) in
            if let da = a.url {
                if let db = b.url {
                    return da.lastPathComponent < db.lastPathComponent
                }
            }
            return true
        }
    }
    
    func allEnlosures(downloaded: Bool) -> [Enclosure] {
        return (dataHelper.entities("Enclosure", matchingPredicate: NSPredicate(format: "downloaded = %d", downloaded)!, managedObjectContext: managedObjectContext)! as [Enclosure]).sorted {(a : Enclosure, b: Enclosure) in
            if let da = a.url {
                if let db = b.url {
                    return da.lastPathComponent < db.lastPathComponent
                }
            }
            return true
        }
    }
    
    func deleteEnclosure(enclosure: Enclosure) {
        enclosure.article.removeEnclosuresObject(enclosure)
        enclosure.article = nil
        self.managedObjectContext.deleteObject(enclosure)
    }
    
    func upsertEnclosures(list: [[String: AnyObject]], article: Article) -> [Enclosure] {
        if let context = article.managedObjectContext {
            return list.map {(item) in
                let enclosure = self.dataHelper.upsertEntity("Enclosure", withProperties: ["url": item["url"]!, "kind": item["type"]!], managedObjectContext: context) as Enclosure
                enclosure.article = article
                article.addEnclosuresObject(enclosure)
                return enclosure
            }
        }
        return []
    }
    
    private var enclosureProgress: [NSObject: Double] = [:]
    
    var enclosureDownloadProgress: Double {
        get {
            let n = Array(enclosureProgress.values).reduce(0.0) {return $0 + $1}
            return n / Double(enclosureProgress.count)
        }
    }
    
    func progressForEnclosure(enclosure: Enclosure) -> Double {
        if let progress = self.enclosureProgress[enclosure.objectID] {
            return progress
        }
        return -1
    }
    
    func updateEnclosure(enclosure: Enclosure, progress: Double) {
        self.enclosureProgress[enclosure.objectID] = progress
    }
    
    func downloadEnclosure(enclosure: Enclosure, progress: (Double) -> (Void) = {(_) in }, completion: (Enclosure, NSError?) -> (Void) = {(_) in }) {
        let downloaded = (enclosure.downloaded == nil ? false : enclosure.downloaded.boolValue)
        if (!downloaded) {
            dataFetcher.fetchItemAtURL(enclosure.url) {(data, error) in
                if let err = error {
                    completion(enclosure, err)
                } else {
                    enclosure.data = data
                    completion(enclosure, nil)
                }
                self.enclosureProgress.removeValueForKey(enclosure.objectID)
            }
            dataFetcher.fetchItemAtURL(enclosure.url) {(data, error) in
                if let err = error {
                    completion(enclosure, err)
                } else if let d = data {
                    enclosure.data = d
                    completion(enclosure, nil)
                }
                self.enclosureProgress.removeValueForKey(enclosure.objectID)
            }.progress {(_, bytesRead, totalBytes) in
                let p = Double(bytesRead) / Double(totalBytes)
                self.updateEnclosure(enclosure, progress: p)
                progress(p)
            }
        } else {
            completion(enclosure, nil)
        }
    }
    
    
    // MARK: Articles
    
    func readArticle(article: Article, read: Bool = true) {
        article.read = read
        article.managedObjectContext?.save(nil)
        setApplicationBadgeCount()
    }
    
    func readArticles(articles: [Article], read: Bool = true) {
        for article in articles {
            article.read = read
        }
        articles.first?.managedObjectContext?.save(nil)
        setApplicationBadgeCount()
    }
    
    func upsertArticle(item: MWFeedItem, context: NSManagedObjectContext) -> Article {
        let properties = ["link": item.link] as [String: AnyObject]
        
        let createProperties = ["published": item.date ?? NSDate(), "read": false] as [String:AnyObject]
        
        let article = self.dataHelper.upsertEntity("Article", withProperties: properties, managedObjectContext: context, createProperties: createProperties) as Article
        
        article.title = item.title ?? ""
        article.link = item.link
        article.updatedAt = item.updated
        article.summary = item.summary
        article.content = item.content
        article.author = item.author
        article.identifier = item.identifier
        
        return article
    }
    
    private var theArticles : [Article]? = nil
    
    private func refreshArticles() {
        theArticles = (dataHelper.entities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: managedObjectContext) as [Article]).sorted {(a : Article, b: Article) in
            if let da = a.updatedAt ?? a.published {
                if let db = b.updatedAt ?? b.published {
                    return da.timeIntervalSince1970 > db.timeIntervalSince1970
                }
            }
            return true
        }
    }
    
    func articles() -> [Article] {
        if theArticles == nil {
            refreshArticles()
        }
        return theArticles!
    }
    
    private var queryFeedResults : [Feed: [Article]]? = nil
    private var reloading = false
    
    func articlesMatchingQuery(query: String, feed: Feed? = nil) -> [Article] {
        if let f = feed {
            if let res = queryFeedResults {
                if let results = res[f] {
                    return results
                } else {
                    queryFeedResults![f] = []
                    if !reloading {
                        reloadQFR()
                    }
                }
            } else {
                queryFeedResults = [f: []]
                reloadQFR()
            }
        } else {
            let results = articlesFromQuery(query, articles: articles())
            if let f = feed {
                if queryFeedResults == nil {
                    queryFeedResults = [:]
                }
                queryFeedResults![f] = results
            }
            return results
        }
        return []
    }
    
    private func articlesFromQuery(query: String, articles: [Article], context: JSContext? = nil) -> [Article] {
        let scriptManager = self.injector!.create(ScriptManager.self) as ScriptManager
        let ctx = context ?? scriptManager.setUpContext(JSContext()!)
        let script = "include = \(query)"
        ctx.evaluateScript(script)
        let function = ctx.objectForKeyedSubscript("include")
        
        let results = articles.filter {(article) in
            let val = function.callWithArguments([article.asDict()])
            return val.toBool()
        }
        return results
    }
    
    // MARK: Background Data Fetch
    
    func managedObjectContextDidSave() {
        theArticles = nil
        reloadQFR()
    }
    
    func reloadQFR() {
        operationQueue.cancelAllOperations()
        if let qfr = queryFeedResults {
            reloading = true
            var feeds : [NSManagedObjectID] = []
            for feed in feedManager.feeds() {
                if feed.query != nil {
                    feeds.append(feed.objectID)
                }
            }
            operationQueue.addOperation(NSBlockOperation(block: {
                self.updateBackgroundThreads(feeds)
            }))
        }
    }
    
    func updateBackgroundThreads(feeds: [NSManagedObjectID]) {
        let articles = dataHelper.entities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: backgroundObjectContext) as [Article]
        var articleIDs : [NSManagedObjectID: [NSManagedObjectID]] = [:]
        for feed in feeds {
            let theFeed = dataHelper.entities("Feed", matchingPredicate: NSPredicate(format: "self == %@", feed)!, managedObjectContext: backgroundObjectContext)!.last! as Feed
            if let query = theFeed.query {
                let res = articlesFromQuery(query, articles: articles, context: self.backgroundContext)
                articleIDs[feed] = res.map { return $0.objectID }
            }
        }
        dispatch_async(dispatch_get_main_queue()) {
            var queryFeedResults : [Feed: [Article]] = [:]
            for (key, value) in articleIDs {
                let theFeed = self.dataHelper.entities("Feed", matchingPredicate: NSPredicate(format: "self == %@", (key as NSManagedObjectID))!, managedObjectContext: self.managedObjectContext)!.last! as Feed
                let articles = self.dataHelper.entities("Article", matchingPredicate: NSPredicate(format: "self IN %@", value)!, managedObjectContext: self.managedObjectContext) as [Article]
                queryFeedResults[theFeed] = articles
            }
            self.queryFeedResults = queryFeedResults
            self.reloading = false
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: nil)
        }
    }
    
    var persistentStoreCoordinator: NSPersistentStoreCoordinator! = nil

    lazy var managedObjectContext: NSManagedObjectContext = {
        self.dataHelper.managedObjectContext(self.persistentStoreCoordinator)
    }()
    
    lazy var operationQueue : NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.underlyingQueue = dispatch_queue_create("DataManager Background Queue", nil)
        return queue
    }()
    
    var backgroundObjectContext: NSManagedObjectContext! = nil
    var backgroundJSVM: JSVirtualMachine? = nil
    var backgroundContext: JSContext? = nil
    
    let dataHelper: CoreDataHelper
    
    lazy var dataFetcher: DataFetcher = DataFetcher()
    
    lazy var feedManager: FeedManager = { self.injector!.create(FeedManager.self) as FeedManager } ()
    
    func setupBackgroundContexts() {
        operationQueue.addOperationWithBlock {
            self.backgroundObjectContext = self.dataHelper.managedObjectContext(self.persistentStoreCoordinator)
            
            self.backgroundJSVM = JSVirtualMachine()
            let scriptManager = ScriptManager()
            self.backgroundContext = scriptManager.setUpContext(JSContext(virtualMachine: self.backgroundJSVM))
            self.managedObjectContextDidSave() // update all the query feeds.
        }
    }
    
    init(dataHelper: CoreDataHelper) {
        self.dataHelper = dataHelper
        
        persistentStoreCoordinator = dataHelper.persistentStoreCoordinator(dataHelper.managedObjectModel())
        
        super.init()
        setupBackgroundContexts()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "managedObjectContextDidSave", name: NSManagedObjectContextDidSaveNotification, object: managedObjectContext)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
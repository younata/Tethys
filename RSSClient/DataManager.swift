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
    
    // MARK: OPML
    
    func importOPML(opml: NSURL) {
        importOPML(opml, progress: {(_) in }, completion: {(_) in })
    }
    
    func importOPML(opml: NSURL, progress: (Double) -> Void, completion: ([Feed]) -> Void) {
        if let text = NSString(contentsOfURL: opml, encoding: NSUTF8StringEncoding, error: nil) {
            let opmlParser = OPMLParser(text: text)
            opmlParser.failure {(error) in
                completion([])
            }
            opmlParser.callback = {(items) in
                var ret : [Feed] = []
                if items.count == 0 {
                    completion([])
                }
                var i = 0
                for item in items {
                    dispatch_async(dispatch_get_main_queue()) {
                        if item.isQueryFeed() {
                            if let query = item.query {
                                let newFeed = self.newQueryFeed(item.title!, code: query, summary: item.summary)
                                newFeed.tags = item.tags
                                ret.append(newFeed)
                            }
                            i++
                            progress(Double(i) / Double(items.count))
                            if i == items.count {
                                completion(ret)
                            }
                        } else {
                            if let feed = item.xmlURL {
                                let newFeed = self.newFeed(feed) {(error) in
                                    if let err = error {
                                        println("error importing \(feed): \(err)")
                                    }
                                    println("imported \(feed)")
                                    i++
                                    progress(Double(i) / Double(items.count))
                                    if i == items.count {
                                        completion(ret)
                                    }
                                }
                                newFeed.tags = item.tags
                                ret.append(newFeed)
                            } else {
                                i++
                                progress(Double(i) / Double(items.count))
                                if i == items.count {
                                    completion(ret)
                                }
                            }
                        }
                    }
                }
            }
            opmlParser.parse()
        }
    }
    
    func generateOPMLContents(feeds: [Feed]) -> String {
        func sanitize(str: String?) -> String {
            if str == nil {
                return ""
            }
            var s = str!
            s = s.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
            s = s.stringByReplacingOccurrencesOfString("'", withString: "&apos;")
            s = s.stringByReplacingOccurrencesOfString("<", withString: "&gt;")
            s = s.stringByReplacingOccurrencesOfString(">", withString: "&lt;")
            s = s.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
            return s
        }
        
        var ret = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n<opml version=\"2.0\">\n    <body>\n"
        for feed in feeds.filter({return $0.query == nil}) {
            if feed.url == nil {
                ret += "        <outline query=\"\(sanitize(feed.query))\" title=\"\(sanitize(feed.title))\" summary=\"\(sanitize(feed.summary))\" type=\"query\""
            } else {
                ret += "        <outline xmlURL=\"\(sanitize(feed.url))\" title=\"\(sanitize(feed.title))\" type=\"rss\""
            }
            if feed.tags != nil {
                let tags : String = ",".join(feed.tags as [String])
                ret += " tags=\"\(tags)\""
            }
            ret += "/>\n"
        }
        ret += "</body>\n</opml>"
        return ret
    }
    
    func writeOPML() {
        self.generateOPMLContents(self.feeds()).writeToFile(NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent("rnews.opml"), atomically: true, encoding: NSUTF8StringEncoding, error: nil)
    }
    
    // MARK: Feeds
    
    func allTags(managedObjectContext: NSManagedObjectContext? = nil) -> [String] {
        let feedsWithTags = dataHelper.entities("Feed", matchingPredicate: NSPredicate(format: "tags != nil")!, managedObjectContext: (managedObjectContext ?? self.managedObjectContext)) as [Feed]
        
        let setOfTags = feedsWithTags.reduce(NSSet()) {(set, feed) in
            return set.setByAddingObjectsFromArray(feed.allTags())
        }
        
        return (setOfTags.allObjects as [String]).sorted { return $0.lowercaseString < $1.lowercaseString }
    }
    
    func feeds(managedObjectContext: NSManagedObjectContext? = nil) -> [Feed] {
        return (dataHelper.entities("Feed", matchingPredicate: NSPredicate(value: true), managedObjectContext: (managedObjectContext ?? self.managedObjectContext)) as [Feed]).sorted {
            if $0.title == nil {
                return true
            } else if $1.title == nil {
                return false
            }
            return $0.title < $1.title
        }
    }
    
    func feedsMatchingTag(tag: String?, managedObjectContext: NSManagedObjectContext? = nil, allowIncompleteTags: Bool = true) -> [Feed] {
        if let theTag = (tag == "" ? nil : tag) {
            return feeds(managedObjectContext: managedObjectContext).filter {
                let tags = $0.allTags()
                for t in tags {
                    if allowIncompleteTags {
                        if t.rangeOfString(theTag) != nil {
                            return true
                        }
                    } else {
                        if t == theTag {
                            return true
                        }
                    }
                }
                return false
            }
        } else {
            return feeds(managedObjectContext: managedObjectContext)
        }
    }
    
    func newFeed(feedURL: String) -> Feed {
        return newFeed(feedURL, completion: {(_) in })
    }
    
    func newFeed(feedURL: String, completion: (NSError?) -> (Void)) -> Feed {
        let predicate = NSPredicate(format: "url = %@", feedURL)
        var feed: Feed! = nil
        if let theFeed = dataHelper.entities("Feed", matchingPredicate: predicate!, managedObjectContext: managedObjectContext)?.last as? Feed {
            feed = theFeed
        } else {
            feed = newFeed()
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
        if let theFeed = dataHelper.entities("Feed", matchingPredicate: predicate!, managedObjectContext: managedObjectContext)?.last as? Feed {
            feed = theFeed
        } else {
            feed = newFeed()
            feed.title = title
            feed.query = code
            feed.summary = summary
            self.managedObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        return feed
    }
    
    func newFeed() -> Feed {
        return NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: managedObjectContext) as Feed
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
    
    func updateFeedsInBackground(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion, backgroundFetch: true)
    }
    
    var parsers : [FeedParser] = []
    
    let mainManager = Manager(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    let backgroundManager = Manager(configuration: NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.rachelbrindle.rNews.background"))
    
    func updateFeeds(feeds: [Feed], completion: (NSError?)->(Void), backgroundFetch: Bool = false) {
        let feedIds = feeds.filter { $0.url != nil }.map { $0.objectID }
        
        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
        dispatch_async(queue) {
            let ctx = self.managedObjectContext
            let theFeeds = self.dataHelper.entities("Feed", matchingPredicate: NSPredicate(format: "self in %@", feedIds)!, managedObjectContext: ctx) as [Feed]
            var feedsLeft = theFeeds.count
            for feed in theFeeds {
                let feedParser = FeedParser(URL: NSURL(string: feed.url)!)
                
                let wait = feed.remainingWait?.integerValue ?? 0
                if wait != 0 {
                    feed.remainingWait = NSNumber(integer: wait - 1)
                    feed.managedObjectContext?.save(nil)
                    println("Skipping feed at \(feed.url)")
                    feedsLeft--
                    continue
                }
                
                var finished : (FeedParser?, NSError?) -> (Void) = {(feedParser: FeedParser?, error: NSError?) in
                    feedsLeft--
                    if error != nil {
                        println("Errored loading: \(error)")
                    }
                    if (feedParser != nil && error == nil) {
                        // set the wait period to zero.
                        //if (error == )
                        if feed.waitPeriod == nil || feed.waitPeriod.integerValue != 0 {
                            feed.waitPeriod = NSNumber(integer: 0)
                            feed.remainingWait = NSNumber(integer: 0)
                            feed.managedObjectContext?.save(nil)
                        }
                    } else if let err = error {
                        if (err.domain == NSURLErrorDomain && err.code > 0) { // FIXME: check the error code for specific HTTP error codes.
                            feed.waitPeriod = NSNumber(integer: (feed.waitPeriod?.integerValue ?? 0) + 1)
                            feed.remainingWait = feed.waitPeriodInRefreshes(feed.waitPeriod.integerValue)
                            println("Setting feed at \(feed.url) to have remainingWait of \(feed.remainingWait) refreshes")
                            feed.managedObjectContext?.save(nil)
                        }
                    }
                    if (feedsLeft == 0) {
                        ctx.save(nil)
                        dispatch_async(dispatch_get_main_queue()) {
                            completion(error)
                            self.setApplicationBadgeCount()
                        }
                    }
                    if let fp = feedParser {
                        self.parsers = self.parsers.filter { $0 != fp }
                    }
                }
                
                self.dataFetcher.fetchFeedAtURL(feed.url, background: backgroundFetch) {(str, error) in
                    if let err = error {
                        finished(nil, error)
                    } else if let s = str {
                        let feedParser = FeedParser(string: s)
                        feedParser.completion = {(info, items) in
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
                            if let feed = self.dataHelper.entities("Feed", matchingPredicate: predicate, managedObjectContext: ctx)?.last as? Feed {
                                feed.title = info.title
                            } else {
                                let feed = (NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: ctx) as Feed)
                                feed.title = info.title
                            }
                            
                            if info.imageURL != nil && feed.feedImage() == nil {
                                self.dataFetcher.fetchImageAtURL(info.imageURL) {(image, error) in
                                    feed.image = image
                                    feed.managedObjectContext?.save(nil)
                                }
                            }
                            
                            feed.summary = summary
                            for item in items {
                                let article = self.upsertArticle(item, context: ctx)
                                if let enclosures = item.enclosures {
                                    self.upsertEnclosures(enclosures as [[String: AnyObject]], article: article)
                                }
                                ctx.save(nil)
                            }
                            
                            finished(feedParser, nil)
                        }
                        feedParser.onFailure = {(error) in
                            finished(feedParser, error)
                        }
                        feedParser.parse()
                        self.parsers.append(feedParser)
                    } else {
                        // str and error are nil.
                        println("Errored loading \(feed.url) with unknown error")
                        self.parsers = self.parsers.filter { $0 != feedParser }
                    }
                }
            }
        }
    }
    
    func estimateNextFeedTime(feed: Feed) -> (NSDate?, Double) { // Time, stddev
        // This could be much better done.
        // For example, some feeds only update on weekdays, which this would tell it to update
        // once every 7/5ths of a day, instead of once a day for 5 days, then not at all on the weekends.
        // But for now, it's ok.
        let times : [NSTimeInterval] = feed.allArticles(self).map {
            return $0.published.timeIntervalSince1970
        }.sorted { return $0 < $1 }
        
        if times.count < 2 {
            return (nil, 0)
        }
        
        func mean(values: [Double]) -> Double {
            return (values.reduce(0.0) { return $0 + $1 }) / Double(values.count)
        }
        
        var intervals : [NSTimeInterval] = []
        for (i, t) in enumerate(times) {
            if i == (times.count - 1) {
                break
            }
            intervals.append(fabs(times[i+1] - t))
        }
        let averageTimeInterval = mean(intervals)
        
        func stdev(values: [Double], average: Double) -> Double {
            return sqrt(mean(values.map { pow($0 - average, 2) }))
        }
        
        let standardDeviation = stdev(intervals, averageTimeInterval)
        
        let d = NSDate(timeIntervalSince1970: times.last! + averageTimeInterval)
        let end = d.dateByAddingTimeInterval(standardDeviation)
        
        if NSDate().compare(end) == NSComparisonResult.OrderedDescending {
            return (nil, 0)
        }
        
        return (NSDate(timeIntervalSince1970: times.last! + averageTimeInterval), standardDeviation)
    }
    
    func setApplicationBadgeCount() {
        let num = feeds(managedObjectContext: managedObjectContext).filter {return !$0.isQueryFeed()}.reduce(0) {return $0 + Int($1.unreadArticles(self))}
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
            mainManager.request(.GET, enclosure.url).response {(_, _, response, error) in
                if let err = error {
                    completion(enclosure, err)
                } else {
                    enclosure.data = response as NSData
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
        let ctx = context ?? setUpContext(JSContext()!)
        let script = "include = \(query)"
        ctx.evaluateScript(script)
        let function = ctx.objectForKeyedSubscript("include")
        
        let results = articles.filter {(article) in
            let val = function.callWithArguments([article.asDict()])
            return val.toBool()
        }
        return results
    }
    
    // MARK: Scripting
    
    private func setUpContext(ctx: JSContext) -> JSContext {
        ctx.exceptionHandler = {(context, value) in
            println("Javascript exception: \(value)")
        }
        ctx.evaluateScript("var console = {}")
        let console = ctx.objectForKeyedSubscript("console")
        var block : @objc_block (NSString) -> Void = {(message: NSString) in println("\(message)")}
        console.setObject(unsafeBitCast(block, AnyObject.self), forKeyedSubscript: "log")
        let script = "var include = function(article) { return true }"
        ctx.evaluateScript(script)
        return ctx
    }
    
    private func console(ctx: JSContext) {
        ctx.evaluateScript("var console = {}")
        let console = ctx.objectForKeyedSubscript("console")
        var block : @objc_block (NSString) -> Void = {(message: NSString) in println("\(message)")}
        console.setObject(unsafeBitCast(block, AnyObject.self), forKeyedSubscript: "log")
    }
    
    private func fetching(ctx: JSContext, isBackground: Bool) {
        let moc = isBackground ? self.backgroundObjectContext! : self.managedObjectContext
        
        ctx.evaluateScript("var data = {onNewFeed: [], onNewArticle: []}")
        let data = ctx.objectForKeyedSubscript("data")
        
        var articles : @objc_block (Void) -> [NSDictionary] = {
            return (self.dataHelper.entities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: moc)! as [Article]).map {return $0.asDict()}
        }
        data.setObject(unsafeBitCast(articles, AnyObject.self), forKeyedSubscript: "articles")
        
        var queryArticles : @objc_block (NSString, [NSObject]) -> [NSDictionary] = {(query, args) in
            let predicate = NSPredicate(format: query, argumentArray: args)
            return (self.dataHelper.entities("Article", matchingPredicate: predicate, managedObjectContext: moc)! as [Article]).map {$0.asDict()}
        }
        data.setObject(unsafeBitCast(queryArticles, AnyObject.self), forKeyedSubscript: "articlesMatchingQuery")
        
        var feeds : @objc_block (Void) -> [NSDictionary] = {
            return (self.dataHelper.entities("Feed", matchingPredicate: NSPredicate(value: true), managedObjectContext: moc)! as [Feed]).map {return $0.asDict()}
        }
        data.setObject(unsafeBitCast(feeds, AnyObject.self), forKeyedSubscript: "feeds")
        
        var queryFeeds : @objc_block (NSString, [NSObject]) -> [NSDictionary] = {(query, args) in // queries for feeds, not to be confused with query feeds.
            let predicate = NSPredicate(format: query, argumentArray: args)
            return (self.dataHelper.entities("Feed", matchingPredicate: predicate, managedObjectContext: moc)! as [Feed]).map {$0.asDict()}
        }
        data.setObject(unsafeBitCast(queryFeeds, AnyObject.self), forKeyedSubscript: "feedsMatchingQuery")
        
        var addOnNewFeed : @objc_block (@objc_block (NSDictionary) -> Void) -> Void = {(block) in
            var onNewFeed = data.objectForKeyedSubscript("onNewFeed").toArray()
            onNewFeed.append(unsafeBitCast(block, AnyObject.self))
            data.setObject(onNewFeed, forKeyedSubscript: "onNewFeed")
        }
        data.setObject(unsafeBitCast(addOnNewFeed, AnyObject.self), forKeyedSubscript: "onNewFeed")
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
            for feed in self.feeds() {
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
    
    let persistentStoreCoordinator: NSPersistentStoreCoordinator! = nil
    let managedObjectContext: NSManagedObjectContext! = nil
    
    let operationQueue = NSOperationQueue()
    var backgroundObjectContext: NSManagedObjectContext! = nil
    var backgroundJSVM: JSVirtualMachine? = nil
    var backgroundContext: JSContext? = nil
    
    let dataHelper: CoreDataHelper
    
    let dataFetcher: DataFetcher
    
    init(dataHelper: CoreDataHelper, dataFetcher: DataFetcher, testing: Bool) {
        
        self.dataHelper = dataHelper
        
        self.dataFetcher = dataFetcher
        
        persistentStoreCoordinator = dataHelper.persistentStoreCoordinator(dataHelper.managedObjectModel(), storeType: (testing ? NSInMemoryStoreType : NSSQLiteStoreType))
        
        for manager in [mainManager, backgroundManager] {
            manager.session.configuration.timeoutIntervalForRequest = 30.0;
            manager.session.configuration.timeoutIntervalForResource = 30.0;
        }
        
        managedObjectContext = dataHelper.managedObjectContext(persistentStoreCoordinator)
        super.init()
        operationQueue.underlyingQueue = dispatch_queue_create("DataManager Background Queue", nil)
        operationQueue.addOperation(NSBlockOperation(block: {
            self.backgroundObjectContext = dataHelper.managedObjectContext(self.persistentStoreCoordinator)
            
            self.backgroundJSVM = JSVirtualMachine()
            self.backgroundContext = self.setUpContext(JSContext(virtualMachine: self.backgroundJSVM))
        }))
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "managedObjectContextDidSave", name: NSManagedObjectContextDidSaveNotification, object: managedObjectContext)
        managedObjectContextDidSave() // update all the query feeds.
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
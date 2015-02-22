//
//  FeedManager.swift
//  RSSClient
//
//  Created by Rachel Brindle on 1/26/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class FeedManager : NSObject {
    let dataHelper : CoreDataHelper = CoreDataHelper()
    let dataFetcher : DataFetcher = DataFetcher()
    
    func allTags(var _ managedObjectContext: NSManagedObjectContext! = nil) -> [String] {
        if managedObjectContext == nil {
            managedObjectContext = self.injector!.create(kMainManagedObjectContext) as NSManagedObjectContext
        }
        let feedsWithTags = dataHelper.entities("Feed", matchingPredicate: NSPredicate(format: "tags != nil")!, managedObjectContext: managedObjectContext) as [Feed]
        
        let setOfTags = feedsWithTags.reduce(NSSet()) {(set, feed) in
            return set.setByAddingObjectsFromArray(feed.allTags())
        }
        
        return (setOfTags.allObjects as [String]).sorted { return $0.lowercaseString < $1.lowercaseString }
    }
    
    func feeds(var _ managedObjectContext: NSManagedObjectContext! = nil) -> [Feed] {
        if managedObjectContext == nil {
            managedObjectContext = self.injector!.create(kMainManagedObjectContext) as NSManagedObjectContext
        }
        return (dataHelper.entities("Feed", matchingPredicate: NSPredicate(value: true), managedObjectContext: managedObjectContext) as [Feed]).sorted {
            if $0.title == nil {
                return true
            } else if $1.title == nil {
                return false
            }
            return $0.title < $1.title
        }
    }
    
    func feedsMatchingTag(tag: String?, var managedObjectContext: NSManagedObjectContext! = nil, allowIncompleteTags: Bool = true) -> [Feed] {
        if managedObjectContext == nil {
            managedObjectContext = self.injector!.create(kMainManagedObjectContext) as NSManagedObjectContext
        }
        if let theTag = (tag == "" ? nil : tag) {
            return feeds(managedObjectContext).filter {
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
            return feeds(managedObjectContext)
        }
    }
    
    func newFeed(feedURL: String, var managedObjectContext: NSManagedObjectContext! = nil, completion: (NSError?) -> (Void)) -> Feed {
        if managedObjectContext == nil {
            managedObjectContext = self.injector!.create(kMainManagedObjectContext) as NSManagedObjectContext
        }
        let predicate = NSPredicate(format: "url = %@", feedURL)
        var feed: Feed! = nil
        if let theFeed = dataHelper.entities("Feed", matchingPredicate: predicate!, managedObjectContext: managedObjectContext)?.last as? Feed {
            feed = theFeed
        } else {
            feed = newFeed(managedObjectContext)
            feed.url = feedURL
            managedObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        return feed
    }
    
    func newQueryFeed(title: String, code: String, var managedObjectContext: NSManagedObjectContext! = nil, summary: String? = nil) -> Feed {
        if managedObjectContext == nil {
            managedObjectContext = self.injector!.create(kMainManagedObjectContext) as NSManagedObjectContext
        }
        let predicate = NSPredicate(format: "title = %@", title)
        var feed: Feed! = nil
        if let theFeed = dataHelper.entities("Feed", matchingPredicate: predicate!, managedObjectContext: managedObjectContext)?.last as? Feed {
            feed = theFeed
        } else {
            feed = newFeed()
            feed.title = title
            feed.query = code
            feed.summary = summary
            feed.managedObjectContext?.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        return feed
    }
    
    func newFeed(var _ managedObjectContext: NSManagedObjectContext! = nil) -> Feed {
        if managedObjectContext == nil {
            managedObjectContext = self.injector!.create(kMainManagedObjectContext) as NSManagedObjectContext
        }
        return NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: managedObjectContext) as Feed
    }
    
    func deleteFeed(feed: Feed) {
        for article in (feed.articles.allObjects as [Article]) {
            feed.managedObjectContext?.deleteObject(article)
        }
        feed.managedObjectContext?.deleteObject(feed)
        feed.managedObjectContext?.save(nil)
    }
    
    func updateFeed(feed: Feed, fromInfo info: MWFeedInfo) {
        var summary : String = ""
        if let s = info.summary {
            let data = s.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
            summary = s
            if let aString = NSAttributedString(data: data, options: options, documentAttributes: nil, error: nil) {
                summary = aString.string
            }
        }
        feed.title = info.title
        feed.summary = summary
        
        if info.imageURL != nil && feed.feedImage() == nil {
            self.dataFetcher.fetchImageAtURL(info.imageURL) {(image, error) in
                feed.image = image
                feed.managedObjectContext?.save(nil)
            }
        }
    }
    
    func updateFeeds(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion)
    }
    
    func updateFeedsInBackground(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion, backgroundFetch: true)
    }
    
    func updateFeeds(feeds: [Feed], completion: (NSError?)->(Void), backgroundFetch: Bool = false) {
        var parsers : [FeedParser] = []
        var feedsLeft = feeds.count
        for feed in feeds {
            let feedParser = FeedParser(URL: NSURL(string: feed.url)!)
            
            let wait = feed.remainingWait?.integerValue ?? 0
            if wait != 0 {
                feed.remainingWait = NSNumber(integer: wait - 1)
                feed.managedObjectContext?.save(nil)
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
                    feed.managedObjectContext?.save(nil)
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(error)
                        let dataManager = self.injector!.create(DataManager.self) as DataManager
                        dataManager.setApplicationBadgeCount()
                    }
                }
                if let fp = feedParser {
                    parsers = parsers.filter { $0 != fp }
                }
            }
            
            self.dataFetcher.fetchFeedAtURL(feed.url, background: backgroundFetch) {(str, error) in
                if let err = error {
                    finished(nil, error)
                } else if let s = str {
                    let feedParser = FeedParser(string: s)
                    feedParser.completion = {(info, items) in
                        
                        self.updateFeed(feed, fromInfo: info)
                        
                        let dataManager = self.injector!.create(DataManager.self) as DataManager
                        
                        for item in items {
                            let article = dataManager.upsertArticle(item, context: feed.managedObjectContext!)
                            if let enclosures = item.enclosures {
                                dataManager.upsertEnclosures(enclosures as [[String: AnyObject]], article: article)
                            }
                            feed.managedObjectContext?.save(nil)
                        }
                        
                        finished(feedParser, nil)
                    }
                    feedParser.onFailure = {(error) in
                        finished(feedParser, error)
                    }
                    feedParser.parse()
                    parsers.append(feedParser)
                } else {
                    // str and error are nil.
                    println("Errored loading \(feed.url) with unknown error")
                    parsers = parsers.filter { $0 != feedParser }
                }
            }
        }
    }
}
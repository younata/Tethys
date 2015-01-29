//
//  FeedManager.swift
//  RSSClient
//
//  Created by Rachel Brindle on 1/26/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class FeedManager {
    let dataHelper : CoreDataHelper
    
    let dataFetcher : DataFetcher
    
    func allTags(managedObjectContext: NSManagedObjectContext) -> [String] {
        let feedsWithTags = dataHelper.entities("Feed", matchingPredicate: NSPredicate(format: "tags != nil")!, managedObjectContext: managedObjectContext) as [Feed]
        
        let setOfTags = feedsWithTags.reduce(NSSet()) {(set, feed) in
            return set.setByAddingObjectsFromArray(feed.allTags())
        }
        
        return (setOfTags.allObjects as [String]).sorted { return $0.lowercaseString < $1.lowercaseString }
    }
    
    func feeds(managedObjectContext: NSManagedObjectContext) -> [Feed] {
        return (dataHelper.entities("Feed", matchingPredicate: NSPredicate(value: true), managedObjectContext: managedObjectContext) as [Feed]).sorted {
            if $0.title == nil {
                return true
            } else if $1.title == nil {
                return false
            }
            return $0.title < $1.title
        }
    }
    
    func feedsMatchingTag(tag: String?, managedObjectContext: NSManagedObjectContext, allowIncompleteTags: Bool = true) -> [Feed] {
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
    
    func newFeed(feedURL: String, managedObjectContext: NSManagedObjectContext, completion: (NSError?) -> (Void)) -> Feed {
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
    
    func newQueryFeed(title: String, code: String, managedObjectContext: NSManagedObjectContext, summary: String? = nil) -> Feed {
        let predicate = NSPredicate(format: "title = %@", title)
        var feed: Feed! = nil
        if let theFeed = dataHelper.entities("Feed", matchingPredicate: predicate!, managedObjectContext: managedObjectContext)?.last as? Feed {
            feed = theFeed
        } else {
            feed = newFeed(managedObjectContext)
            feed.title = title
            feed.query = code
            feed.summary = summary
            managedObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        return feed
    }
    
    func newFeed(managedObjectContext: NSManagedObjectContext) -> Feed {
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

    init(dataHelper: CoreDataHelper, dataFetcher: DataFetcher) {
        self.dataHelper = dataHelper
        self.dataFetcher = dataFetcher
    }
}
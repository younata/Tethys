//
//  Feed.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

#if os(iOS)
    typealias Image=UIImage
#elseif os(OSX)
    typealias Image=NSImage
#endif

class FeedObject {
    var title : String = ""
    var url : String? = nil
    var summary : String = ""
    var query : String? = nil
    var tags : [String] = []
    var waitPeriod : Int = 0 // in retries
    var remainingWait : Int = 0 // in retries
    var image : Image? = nil
    var articles : [ArticleObject] = []

    let objectID : NSManagedObjectID

    var isQueryFeed : Bool {
        return self.query == nil
    }

    var feedTitle : String {
        return reduce(tags, self.title) {
            if $1.hasPrefix("~") {
                return $1.substringFromIndex($1.startIndex.successor())
            }
            return $0
        }
    }

    var feedSummary : String {
        return reduce(tags, self.summary) {
            if $1.hasPrefix("`") {
                return $1.substringFromIndex($1.startIndex.successor())
            }
            return $0
        }
    }

    var waitPeriodInRefreshes : Int {
        var ret = 0, next = 1
        let wait = max(0, waitPeriod - 2)
        for i in 0..<wait {
            (ret, next) = (next, ret+next)
        }
        return ret
    }

    func unreadArticles() -> [ArticleObject] {
        return articles.filter { return $0.read == false }
    }

    func updateFromFeed(feed: Feed) {
        if feed.objectID != objectID {
            return
        }
        title = feed.title
        url = feed.url
        query = feed.query
        tags = feed.tags as [String]
        waitPeriod = feed.waitPeriod.integerValue
        remainingWait = feed.remainingWait.integerValue
        image = feed.image != nil ? feed.image as? Image : nil
    }

    func synchronizeWithFeed(feed: Feed) {
        if feed.objectID != objectID {
            return
        }
        feed.title = title
        feed.url = url
        feed.query = query
        feed.tags = tags
        feed.waitPeriod = waitPeriod
        feed.remainingWait = remainingWait
        feed.image = image
        feed.managedObjectContext?.save(nil)
    }

    init(tuple: (title: String, url: String?, summary: String, query: String?, tags: [String], waitPeriod: Int, remainingWait: Int, image: Image?), objectID: NSManagedObjectID) {
        title = tuple.title
        url = tuple.url
        query = tuple.query
        tags = tuple.tags
        waitPeriod = tuple.waitPeriod
        remainingWait = tuple.remainingWait
        image = tuple.image
        self.objectID = objectID
    }

    init(feed: Feed) {
        objectID = feed.objectID
        updateFromFeed(feed)
    }
}
//
//  FeedManagerMock.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation


class FeedManagerMock : FeedManager {
    override func allTags(managedObjectContext: NSManagedObjectContext) -> [String] {
        return []
    }

    override func feeds(managedObjectContext: NSManagedObjectContext) -> [Feed] {
        return []
    }

    override func feedsMatchingTag(tag: String?, managedObjectContext: NSManagedObjectContext, allowIncompleteTags: Bool) -> [Feed] {
        return []
    }

    override func newFeed(feedURL: String, managedObjectContext: NSManagedObjectContext, completion: (NSError?) -> (Void)) -> Feed {
        return Feed()
    }

    override func newQueryFeed(title: String, code: String, managedObjectContext: NSManagedObjectContext, summary: String?) -> Feed {
        return Feed()
    }

    override func newFeed(managedObjectContext: NSManagedObjectContext) -> Feed {
        return Feed()
    }

    override func deleteFeed(feed: Feed) {

    }

    override func updateFeed(feed: Feed, fromInfo info: MWFeedInfo) {
        
    }
}
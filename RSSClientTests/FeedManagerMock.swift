//
//  FeedManagerMock.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation


class FeedManagerMock : FeedManager {
    override func allTags(var _ managedObjectContext: NSManagedObjectContext! = nil) -> [String] {
        return []
    }

    override func feeds(var _ managedObjectContext: NSManagedObjectContext! = nil) -> [Feed] {
        return []
    }

    override func feedsMatchingTag(tag: String?, var managedObjectContext: NSManagedObjectContext! = nil, allowIncompleteTags: Bool) -> [Feed] {
        return []
    }

    override func newFeed(feedURL: String, managedObjectContext: NSManagedObjectContext, completion: (NSError?) -> (Void)) -> Feed {
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
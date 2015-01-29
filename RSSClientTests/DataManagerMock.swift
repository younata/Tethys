//
//  DataManagerMock.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class DataManagerMock : DataManager {
    override func importOPML(opml: NSURL) {

    }

    override func importOPML(opml: NSURL, progress: (Double) -> Void, completion: ([Feed]) -> Void) {
    }

    override func writeOPML() {

    }

    override func allTags(#managedObjectContext: NSManagedObjectContext?) -> [String] {
        return []
    }

    override func feeds(#managedObjectContext: NSManagedObjectContext?) -> [Feed] {
        return []
    }

    override func feedsMatchingTag(tag: String?, managedObjectContext: NSManagedObjectContext?, allowIncompleteTags: Bool) -> [Feed] {
        return []
    }

    override func updateFeeds(completion: (NSError?) -> (Void)) {
        completion(nil)
    }

    override func updateFeedsInBackground(completion: (NSError?) -> (Void)) {
        completion(nil)
    }

    override func updateFeeds(feeds: [Feed], completion: (NSError?) -> (Void), backgroundFetch: Bool) {
        completion(nil)
    }
}
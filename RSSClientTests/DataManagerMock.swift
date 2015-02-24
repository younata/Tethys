//
//  DataManagerMock.swift
//  RSSClient
//
//  Created by pivotal on 1/29/15.
//  Copyright (c) 2015 Rachel Brindle. All rights reserved.
//

import Foundation

class DataManagerMock : DataManager {
    override func feeds(managedObjectContext: NSManagedObjectContext? = nil) -> [Feed] {
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
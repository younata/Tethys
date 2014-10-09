//
//  DataManagerTests.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import XCTest

class DataManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        for feed in DataManager.sharedInstance().feeds() {
            DataManager.sharedInstance().deleteFeed(feed)
        }
        for group in DataManager.sharedInstance().groups() {
            DataManager.sharedInstance().deleteGroup(group)
        }
    }
    
    // MARK: - Feeds
    
    func testCreateFeeds() {
        let rss1URL = ""
        let rss2URL = ""
        let atomURL = ""
        for url in [rss1URL, rss2URL, atomURL] {
            let feed = DataManager.sharedInstance().newFeed(url)
            XCTAssertNotNill(feed, "creating new feeds, should not be nil")
        }
        XCTAssertEqual(DataManager.sharedInstance().feeds().count, 3, "Should have created and saved 3 feeds")
        DataManager.sharedInstance().newFeed(rss1URL)
        XCTAssertEqual(DataManager.sharedInstance().feeds().count, 3, "Should not have added a duplicate feed")
    }
    
    let feedURL = ""
    let otherFeedURL = ""
    
    func testDeleteFeed() {
        let originalCount = DataManager.sharedInstance().feeds().count
        let feed = DataManager.sharedInstance().newFeed(feedURL)
        XCTAssertEqual(DataManager.sharedInstance().feeds().count, originalCount + 1, "Should have stored 1 more feed")
        DataManager.sharedInstance().deleteFeed(feed)
        XCTAssertEqual(DataManager.sharedInstance().feeds().count, originalCount, "Should have deleted stored feed")
    }
    
    func testUpdateAllFeeds() {
        let feed = DataManager.sharedInstance().newFeed(feedURL)
        let otherFeed = DataManager.sharedInstance().newFeed(otherFeedURL)
        let expectation = expectationWithDescription("Update all feeds")
        let completion: (Void) -> (Void) = {
            expectation.fulfill()
        }
        DataManager.sharedInstance().updateFeeds(completion)
        waitForExpectationsWithTimeout(60, handler: {error in
            // blep
        })
    }
    
    func testUpdateSomeFeeds() {
        let feed = DataManager.sharedInstance().newFeed(feedURL)
        let otherFeed = DataManager.sharedInstance().newFeed(otherFeedURL)
        let expectation = expectationWithDescription("Update all feeds")
        let completion: (Void) -> (Void) = {
            expectation.fulfill()
        }
        DataManager.sharedInstance().updateFeeds([feed], completion: completion)
        waitForExpectationsWithTimeout(60, handler: {error in
            // blep
        })
    }
    
    // MARK: - Groups
    
    func testCreateGroups() {
        let origCount = DataManager.sharedInstance().groups().count
        
        let group = DataManager.newGroup("test")
        
        XCTAssertEqual(DataManager.sharedInstance().groups().count, origCount + 1, "should add group")
        
        let otherGroup = DataManager.newGroup("test")
        XCTAssertEqual(otherGroup, group, "Adding group with dupe name should return original group")
        XCTAssertEqual(DataManager.sharedInstance().groups().count, origCount + 1, "adding group with dupe name should not create a new group")
    }
    
    func testAddingFeedsToGroups() {
        let feed = DataManager.sharedInstance().newFeed(feedURL)
        let group = DataManager.newGroup("test")

        DataManager.sharedInstance().addFeed(feed, toGroup: group)
        XCTAssert(feed.groups.containsObject(group), "adding a feed to a group should add the group to the feed's groups set")
        XCTAssert(group.feeds.containsObject(feed), "adding a feed to a group should add the feed to the group's feeds set")
    }
    
    func testDeleteGroup() {
        let feed = DataManager.sharedInstance().newFeed(feedURL)
        let group = DataManager.newGroup("test")
        
        DataManager.sharedInstance().addFeed(feed, toGroup: group)
        
        let origCount = DataManager.sharedInstance().groups().count

        DataManager.sharedInstance().deleteGroup(group)
        XCTAssertEqual(DataManager.sharedInstance().groups().count, origCount - 1, "Deleting feed should remove it from storage")
        XCTAssertFalse(feed.groups.containsObject(group), "deleting group should remove it from any feed's groups set")
        XCTAssert(contains(DataManager.sharedInstance().feeds(), feed), "")
    }
    
    func testDeleteFeedGroup() {
        let feed = DataManager.sharedInstance().newFeed(feedURL)
        let group = DataManager.newGroup("test")
        
        DataManager.sharedInstance().addFeed(feed, toGroup: group)

        DataManager.sharedInstance().deleteFeed(feed)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }

}

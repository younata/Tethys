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
    
    let dataManager = DataManager()
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        for feed in dataManager.feeds() {
            dataManager.deleteFeed(feed)
        }
        for group in dataManager.groups() {
            dataManager.deleteGroup(group)
        }
    }
    
    // MARK: - Feeds
    
    func testCreateFeeds() {
        let rss1URL = "a"
        let rss2URL = "b"
        let atomURL = "c"
        for url in [rss1URL, rss2URL, atomURL] {
            let feed = dataManager.newFeed(url)
            XCTAssertNotNil(feed, "creating new feeds, should not be nil")
        }
        XCTAssertEqual(dataManager.feeds().count, 3, "Should have created and saved 3 feeds")
        let n = dataManager.feeds().count
        dataManager.newFeed(rss1URL)
        XCTAssertEqual(dataManager.feeds().count, n, "Should not have added a duplicate feed")
    }
    
    let feedURL = ""
    let otherFeedURL = ""
    
    func testDeleteFeed() {
        let originalCount = dataManager.feeds().count
        let feed = dataManager.newFeed(feedURL)
        XCTAssertEqual(dataManager.feeds().count, originalCount + 1, "Should have stored 1 more feed")
        dataManager.deleteFeed(feed)
        XCTAssertEqual(dataManager.feeds().count, originalCount, "Should have deleted stored feed")
    }
    
    func testUpdateAllFeeds() {
        let feed = dataManager.newFeed(feedURL)
        let otherFeed = dataManager.newFeed(otherFeedURL)
        let expectation = expectationWithDescription("Update all feeds")
        let completion: (NSError?) -> (Void) = {(_) in
            expectation.fulfill()
        }
        dataManager.updateFeeds(completion)
        waitForExpectationsWithTimeout(60, handler: {error in
            // blep
        })
    }
    
    func testUpdateSomeFeeds() {
        let feed = dataManager.newFeed(feedURL)
        let otherFeed = dataManager.newFeed(otherFeedURL)
        let expectation = expectationWithDescription("Update all feeds")
        let completion: (NSError?) -> (Void) = {(_) in
            expectation.fulfill()
        }
        dataManager.updateFeeds([feed], completion: completion)
        waitForExpectationsWithTimeout(60, handler: {error in
            // blep
        })
    }
    
    // MARK: - Groups
    
    func testCreateGroups() {
        let origCount = dataManager.groups().count
        
        let group = dataManager.newGroup("test")
        
        XCTAssertEqual(dataManager.groups().count, origCount + 1, "should add group")
        
        let otherGroup = dataManager.newGroup("test")
        XCTAssertEqual(otherGroup, group, "Adding group with dupe name should return original group")
        XCTAssertEqual(dataManager.groups().count, origCount + 1, "adding group with dupe name should not create a new group")
    }
    
    func testAddingFeedsToGroups() {
        let feed = dataManager.newFeed(feedURL)
        let group = dataManager.newGroup("test")

        dataManager.addFeed(feed, toGroup: group)
        XCTAssert(feed.groups.containsObject(group), "adding a feed to a group should add the group to the feed's groups set")
        XCTAssert(group.feeds.containsObject(feed), "adding a feed to a group should add the feed to the group's feeds set")
    }
    
    func testDeleteGroup() {
        let feed = dataManager.newFeed(feedURL)
        let group = dataManager.newGroup("test")
        
        dataManager.addFeed(feed, toGroup: group)
        
        let origCount = dataManager.groups().count

        dataManager.deleteGroup(group)
        XCTAssertEqual(dataManager.groups().count, origCount - 1, "Deleting feed should remove it from storage")
        XCTAssertFalse(feed.groups.containsObject(group), "deleting group should remove it from any feed's groups set")
        XCTAssert(contains(dataManager.feeds(), feed), "")
    }
    
    func testDeleteFeedGroup() {
        let feed = dataManager.newFeed(feedURL)
        let group = dataManager.newGroup("test")
        
        dataManager.addFeed(feed, toGroup: group)

        dataManager.deleteFeed(feed)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }

}

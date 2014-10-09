//
//  FeedTableCellTests.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import XCTest

class FeedTableCellTests: XCTestCase {
    
    var cell : FeedTableCell = FeedTableCell()

    override func setUp() {
        super.setUp()
        cell = FeedTableCell(style: .Plain, reuseIdentifier: "")
    }
    
    func testFeedNil() {
        cell.feed = nil
        XCTAssertNil(cell.iconView.image, "iconView image should be nil")
        XCTAssertEqual(cell.nameLabel.text, "", "nameLabel text should be empty string")
        XCTAssertEqual(cell.summaryLabel.text, "", "summaryLabel text should be empty string")
        XCTAssertEqual(cell.unreadCounter.unread, 0, "unreadcounter unread count should be 0")
    }
    
    func testFeed() {
        let feed = FakeFeed()
        cell.feed = feed
        XCTAssertEqual(feed.image, cell.iconView.image, "iconView image should equal feed image")
        XCTAssertEqual(feed.title, cell.nameLabel.text, "nameLabel text should equal feed title")
        XCTAssertEqual(3, cell.unreadCounter.unread, "unreadcounter unread count should equal number of unread feeds")
        XCTAssertEqual(feed.summary, cell.summaryLabel.text, "summaryLabel text should equal feed summary")
    }
}

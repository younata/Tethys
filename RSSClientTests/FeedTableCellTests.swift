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
    
    var cell : FeedTableCell = FeedTableCell(style: .Default, reuseIdentifier: "cell")

    override func setUp() {
        super.setUp()
        cell = FeedTableCell(style: .Default, reuseIdentifier: "")
    }
    
    func testFeedNil() {
        cell.feed = nil
        XCTAssertNil(cell.iconView.image, "iconView image should be nil")
        XCTAssertEqual(cell.nameLabel.text!, "", "nameLabel text should be empty string")
        XCTAssertEqual(cell.summaryLabel.text!, "", "summaryLabel text should be empty string")
        XCTAssertEqual(cell.unreadCounter.unread, UInt(0), "unreadcounter unread count should be 0")
    }
    
    func testFeed() {
        let feed = FakeFeed.newFeed()
        cell.feed = feed
        if feed.image != nil && cell.iconView.image != nil {
            XCTAssertEqual(feed.image! as UIImage, cell.iconView.image!, "iconView image should equal feed image")
        }
        XCTAssertEqual(feed.title!, cell.nameLabel.text!, "nameLabel text should equal feed title")
        XCTAssertEqual(UInt(3), cell.unreadCounter.unread, "unreadcounter unread count should equal number of unread feeds")
        if feed.summary != nil && cell.summaryLabel.text != nil {
            XCTAssertEqual(feed.summary!, cell.summaryLabel.text!, "summaryLabel text should equal feed summary")
        } else if !(feed.summary == nil && cell.summaryLabel.text == nil) {
            XCTFail("summaryLabel text should equal feed summary, and one of them is nil")
        }
    }
}

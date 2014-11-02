//
//  ArticleCellTests.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import XCTest

class ArticleCellTests: XCTestCase {
    
    var cell : ArticleCell = ArticleCell(style: .Default, reuseIdentifier: "")

    override func setUp() {
        super.setUp()
        cell = ArticleCell(style: .Default, reuseIdentifier: "")
    }
    
    func testArticleNil() {
        cell.article = nil
        XCTAssertEqual(cell.title.text!, "", "title text should be empty string")
        XCTAssertEqual(cell.published.text!, "", "published text should be empty string")
        XCTAssertEqual(cell.author.text!, "", "author text should be empty string")
    }
    
    func testArticle() {
        let article = newArticle(read: false)
        cell.article = article
        let dateParser = NSDateFormatter()
        dateParser.timeStyle = .NoStyle
        dateParser.dateStyle = .ShortStyle
        dateParser.timeZone = NSCalendar.currentCalendar().timeZone
        XCTAssertEqual(cell.title.text!, article.title!, "title text should be empty string")
        XCTAssertEqual(cell.published.text!, dateParser.stringFromDate(article.published!), "published text should be empty string")
        XCTAssertEqual(cell.author.text!, article.author!, "author text should be empty string")
        XCTAssertEqual(cell.unreadWidth.constant, cell.unread.bounds.size.width * -1, "should show unread flag")
    }
    
    func testReadArticle() {
        let article = newArticle(read: false)
        cell.article = article
        XCTAssertEqual(cell.unreadWidth.constant, CGFloat(0), "should hide unread flag")
    }
}

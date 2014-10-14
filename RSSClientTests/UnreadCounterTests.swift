//
//  UnreadCounterTests.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import XCTest

class UnreadCounterTests: XCTestCase {
    
    var counter : UnreadCounter = UnreadCounter(frame: CGRectZero)

    override func setUp() {
        super.setUp()
        counter = UnreadCounter(frame: CGRectZero)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testInit() {
        let label : UILabel = counter.countLabel
        XCTAssert(label.text == "" || label.text == nil, "Label should not contain text")
        XCTAssert(label.textColor == counter.countColor, "Label color should default to count color")
        let clColor = UIColor(CGColor: counter.circleLayer.strokeColor)
        XCTAssertEqual(clColor, UIColor.clearColor(), "circle layer stroke color should always be clear")
        XCTAssertEqual(counter.backgroundColor!, UIColor.clearColor(), "Background Color should be clear")
    }
    
    func testChangeText() {
        let label : UILabel = counter.countLabel
        counter.circleColor = UIColor.greenColor()
        counter.unread = 2
        let clColor = UIColor(CGColor: counter.circleLayer.fillColor)
        XCTAssertEqual(clColor, counter.circleColor, "fill color should equal the circle color")
        counter.circleColor = UIColor.whiteColor()
        XCTAssertNotEqual(clColor, counter.circleColor, "fill color should equal the circle color")
        for i in 1...100 {
            counter.unread = UInt(i)
            XCTAssert(label.text == "\(i)", "label text should be the string representation of the unread number")
        }
        XCTAssertEqual(clColor, counter.circleColor, "fill color should equal the circle color")
    }
    
    func testChangePath() {
        XCTAssertNil(counter.circleLayer.path, "Path should not be defined before layout subviews")
        counter.bounds = CGRectMake(0, 0, 4, 4)
        counter.layoutSubviews()
        XCTAssertNotNil(counter.circleLayer.path, "Path should be defined after layout subviews")
    }
}

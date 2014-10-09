//
//  AppDelegateTests.swift
//  RSSClient
//
//  Created by Rachel Brindle on 10/8/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit
import XCTest

class AppDelegateTests: XCTestCase {
    
    var appDelegate: AppDelegate

    override func setUp() {
        super.setUp()
        
        appDelegate = AppDelegate()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testApplicationDidFinishLoading() {
        appDelegate.application(nil, didFinishLaunchingWithOptions: nil)
        XCTAssertNotNil(appDelegate.window, "App Delegate should have a window")
        XCTAssert(appDelegate.window!.rootViewController?.isKindOfClass(UINavigationController.self), "App should start with a navigation controller")
    }

    func testExample() {
        XCTAssert(true, "Pass")
    }

    func testPerformanceExample() {
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }

}

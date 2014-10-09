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
    
    var appDelegate: AppDelegate = AppDelegate()

    override func setUp() {
        super.setUp()
        
        appDelegate = AppDelegate()
    }
    
    func testApplicationDidFinishLoading() {
        appDelegate.application(nil, didFinishLaunchingWithOptions: nil)
        XCTAssertNotNil(appDelegate.window, "App Delegate should have a window")
        XCTAssert(appDelegate.window!.rootViewController?.isKindOfClass(UINavigationController.self), "App should start with a navigation controller")
        let nc = (appDelegate.window!.rootViewController! as UINavigationController)
        XCTAssert(nc.viewControllers.last!.isKindOfClass(FeedsTableViewController.self), "Feeds Table controller should be root view controller of the navigation controller")
    }
    
    func testBackgroundFetch() {
        XCTFail("Implement background fetch tests")
    }
}

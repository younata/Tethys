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
    var app = UIApplication.sharedApplication()

    override func setUp() {
        super.setUp()
        
        appDelegate = AppDelegate()
        app = UIApplication.sharedApplication()
    }
    
    func testNormalLoad() {
        appDelegate.application(app, didFinishLaunchingWithOptions: nil)
        XCTAssertNotNil(appDelegate.window, "App Delegate should have a window")
        XCTAssert(appDelegate.window!.rootViewController!.isKindOfClass(UINavigationController.self), "App should start with a navigation controller")
        let nc = (appDelegate.window!.rootViewController! as UINavigationController)
        XCTAssert(nc.viewControllers.last!.isKindOfClass(FeedsTableViewController.self), "Feeds Table controller should be root view controller of the navigation controller")
    }
    
    func testNotificationLoad() {
        let note = UILocalNotification();
        let feed = FakeFeed()
        let article = (feed.articles!.anyObject() as Article)
        note.userInfo = ["feed": feed, "article": article]
        appDelegate.application(app, didFinishLaunchingWithOptions: [UIApplicationLaunchOptionsLocalNotificationKey: note])
        XCTAssert((appDelegate.window!.rootViewController! as UINavigationController).visibleViewController.isKindOfClass(ArticleViewController.self), "")
        let al = ((appDelegate.window!.rootViewController! as UINavigationController).visibleViewController as ArticleViewController)
        XCTAssertNotNil(al.article, "should have an article")
        XCTAssertEqual(al.article!, article, "should display article")
    }
    
    func testBackgroundFetch() {
        XCTFail("not implemented in a satisfactory way")
        // set up...
        let expectation = expectationWithDescription("background fetch")
        let notes = app.scheduledLocalNotifications
        appDelegate.application(app, performFetchWithCompletionHandler: {(res: UIBackgroundFetchResult) in
            expectation.fulfill()
            if res == .NoData || res == .Failed {
                XCTAssertEqual(self.app.scheduledLocalNotifications.count, notes.count, "should have equal number of scheduled notifications")
            } else if res == .NewData {
                XCTAssertGreaterThan(self.app.scheduledLocalNotifications.count, notes.count, "should have shown local notifications")
            } else {
                XCTFail("unknown result")
            }
        })
        
        waitForExpectationsWithTimeout(60, handler: {(error) in
        })
    }
}

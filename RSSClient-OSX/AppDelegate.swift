//
//  AppDelegate.swift
//  RSSClient-OSX
//
//  Created by Rachel Brindle on 11/12/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    var mainController: MainController? = nil

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        mainController = MainController(window: self.window)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
}


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
    
    @IBOutlet var mainController: MainController? = nil
    
    var dataManager = DataManager() // var is only because of testing...

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        mainController?.window = window
        mainController?.configure(dataManager)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func applicationDockMenu(sender: NSApplication) -> NSMenu? {
        return nil
    }
    
    func openFile(filename: String, finish: ([Feed]) -> (Void)) -> Bool {
        /*
        if let string = NSString(contentsOfFile: filename, encoding: NSUTF8StringEncoding, error: nil) {
            let semaphore = dispatch_semaphore_create(0)
            var ret = false
            let opmlParser = OPMLParser(text: string)
            opmlParser.success {(_) in
                ret = true
                dispatch_semaphore_signal(semaphore)
            }
            opmlParser.failure {(_) in
                dispatch_semaphore_signal(semaphore)
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            if ret {
                DataManager.sharedInstance().importOPML(NSURL(fileURLWithPath: filename)!, progress: {(_) in }, completion: finish)
            }
            return ret
        }*/
        return false
    }
    
    func application(sender: NSApplication, openFile filename: String) -> Bool {
        return false
        return openFile(filename) {(feeds) in }
    }
    
    func application(sender: AnyObject, openFileWithoutUI filename: String) -> Bool {
        return openFile(filename) {(_) in }
    }
}


//
//  FeedsList.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/21/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Cocoa

class FeedsList: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var feeds : [Feed] = []
    
    weak var tableView: NSTableView? = nil {
        didSet {
            tableView?.setDelegate(self)
            tableView?.setDataSource(self)
        }
    }
    
    var dataManager : DataManager? = nil
    
    override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reload", name: "UpdatedFeed", object: nil)
    }
    
    func reload() {
        feeds = dataManager?.feeds().sorted {(f1: Feed, f2: Feed) in
            let f1Unread = f1.unreadArticles(self.dataManager!)
            let f2Unread = f2.unreadArticles(self.dataManager!)
            if f1Unread != f2Unread {
                return f1Unread > f2Unread
            }
            if f1.title == nil {
                return true
            } else if f2.title == nil {
                return false
            }
            return f1.title < f2.title
        } ?? []
        if feeds.count == 0 {
            
        }
        tableView?.reloadData()
    }
    
    // MARK: NSTableViewDelegate
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return NSView()
    }
    
    func tableView(tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return nil
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 100
    }
    
    func tableView(tableView: NSTableView, shouldSelectRow rowIndex: Int) -> Bool {
        return false
    }
    
    // MARK: NSTableViewDataSource
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return feeds.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn aTableColumn: NSTableColumn?, row rowIndex: Int) -> AnyObject? {
        let feedView = FeedView(frame: NSMakeRect(0, 0, 0, 0))
        feedView.feed = feeds[rowIndex]
        return feedView
    }
}

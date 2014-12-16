//
//  MainController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 11/18/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import Cocoa

class MainController: NSResponder, NSTextViewDelegate {
    @IBOutlet var window : NSWindow? = nil
    
    let feedsList = FeedsList()
    
    @IBOutlet var tableView : NSTableView? = nil
    
    let commandView = NSTextView(forAutoLayout: ())
    var commandHeight : NSLayoutConstraint? = nil
    
    @IBOutlet var tableLeftEdge : NSLayoutConstraint? = nil
    
    @IBOutlet var splitView : NSSplitView? = nil
    
    var dataManager : DataManager? = nil
    
    override var acceptsFirstResponder : Bool {
        get {
            return true
        }
    }
    
    func configure(dataManager: DataManager) {
        self.dataManager = dataManager
        feedsList.dataManager = dataManager
        feedsList.tableView = tableView!
        feedsList.reload()
        feedsList.onFeedSelection = showFeeds
        
        window?.makeFirstResponder(self)
        
        // add everything on top of this...
        window?.contentView.addSubview(commandView)
        commandView.autoPinEdgesToSuperviewEdgesWithInsets(NSEdgeInsetsZero, excludingEdge: .Top)
        commandHeight = commandView.autoSetDimension(.Height, toSize: 0)
    }
    
    @IBAction func openDocument(sender: AnyObject) {
        // open a feed or opml file and import that...
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["xml", "opml"]
        panel.beginSheetModalForWindow(self.window!) {(result) in
            if result == NSFileHandlingPanelOKButton {
                for url in panel.URLs as [NSURL] {
                    self.dataManager?.importOPML(url)
                }
            }
        }
    }
    
    let articleList = NSTableView(forAutoLayout: ())
    
    func showFeeds(feed: Feed) {
        
    }
    
    // MARK: NSTextViewDelegate
    
    func textView(textView: NSTextView, completions words: [AnyObject], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [AnyObject] {
        return []
    }
    
    func textView(textView: NSTextView, shouldChangeTextInRange affectedCharRange: NSRange, replacementString: String) -> Bool {
        let text = (textView.string! as NSString).stringByReplacingCharactersInRange(affectedCharRange, withString: replacementString)
        if let font = textView.font {
            let height = (text as NSString).sizeWithAttributes([NSFontAttributeName as NSString: font]).height
            commandHeight?.constant = height
        }
        if replacementString.rangeOfString("\n") != nil {
            // extract and execute the command.
        }
        return true
    }
}

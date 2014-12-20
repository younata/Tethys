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
    
    @IBOutlet var splitView : NSSplitView? = nil
    
    @IBOutlet var leftView : NSView? = nil
    @IBOutlet var navigationBar : BackgroundView? = nil
    @IBOutlet var navigationTitle : NSTextField? = nil
    
    @IBOutlet var backButton : NSButton? = nil
    
    let commandView = NSTextView(forAutoLayout: ())
    var commandHeight : NSLayoutConstraint? = nil
    
    var dataManager : DataManager? = nil
    
    @IBOutlet var rightView : NSView? = nil
    
    let rightNavBar = BackgroundView(forAutoLayout: ())
    let rightNavTitle = NSTextField(forAutoLayout: ())
    
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
        feedsList.onFeedSelection = showArticles
        
        window?.makeFirstResponder(self)
        
        for view in [tableView, splitView, leftView, navigationBar, navigationTitle, backButton, commandView] {
            if let v = view {
                v.wantsLayer = true
            }
        }
        
        // add everything on top of this...
        window?.contentView.addSubview(commandView)
        commandView.autoPinEdgesToSuperviewEdgesWithInsets(NSEdgeInsetsZero, excludingEdge: .Top)
        commandHeight = commandView.autoSetDimension(.Height, toSize: 0)
        
        navigationBar?.alphaValue = 1.0
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
    
    var articleTableView : NSTableView? = nil
    var articleScrollView : NSScrollView? = nil
    let articleList = ArticlesList()
    var articleListConstraint : NSLayoutConstraint? = nil
    
    func showArticles(feed: Feed) {
        if articleTableView != nil {
            return
        }
        articleScrollView = NSScrollView(forAutoLayout: ())
        leftView?.addSubview(articleScrollView!)
        
        articleTableView = NSTableView(forAutoLayout: ())
        articleTableView?.wantsLayer = true
        articleTableView?.gridStyleMask = .SolidHorizontalGridLineMask
        articleScrollView?.addSubview(articleTableView!)
        articleTableView?.autoPinEdgesToSuperviewEdgesWithInsets(NSEdgeInsetsZero)
        
        articleScrollView?.autoPinEdge(.Top, toEdge: .Bottom, ofView: navigationBar)
        articleScrollView?.autoPinEdgeToSuperviewEdge(.Bottom)
        articleScrollView?.autoMatchDimension(.Width, toDimension: .Width, ofView: leftView!)
        let inset = -(leftView!.bounds.width)
        let rightConstraint = articleScrollView?.autoPinEdgeToSuperviewEdge(.Right, withInset: inset)
        
        let tableColumn = NSTableColumn(identifier: "articles")
        tableColumn.resizingMask = .AutoresizingMask
        
        articleTableView?.addTableColumn(tableColumn)
        
        articleScrollView?.documentView = articleTableView
        articleScrollView?.hasVerticalScroller = true
        
        articleList.dataManager = dataManager
        articleList.tableView = articleTableView
        articleList.feeds = [feed]
        articleList.onSelection = showArticle
        backButton?.alphaValue = 0.0
        backButton?.hidden = false
        navigationTitle?.stringValue = NSLocalizedString("Articles", comment: "")
        leftView?.layout()
        rightConstraint?.constant = 0
        NSAnimationContext.runAnimationGroup({(ctx) in
            ctx.duration = 0.2
            self.leftView?.needsLayout = true
            self.backButton?.alphaValue = 1.0
        }) {
            self.articleList.reload()
        }
        articleListConstraint = rightConstraint
    }
    
    @IBAction func showFeeds(sender: NSObject) {
        if articleTableView == nil {
            return
        }
        let inset = -(leftView!.bounds.width)
        articleListConstraint?.constant = inset
        NSAnimationContext.runAnimationGroup({(ctx) in
            ctx.duration = 0.2
            self.leftView?.needsLayout = true
            self.backButton?.alphaValue = 0.0
        }) {
            print("")
            self.articleScrollView?.removeFromSuperview()
            self.articleScrollView = nil
            self.articleTableView?.removeFromSuperview()
            self.articleTableView = nil
            self.backButton?.hidden = true
            self.navigationTitle?.stringValue = NSLocalizedString("Feeds", comment: "")
        }
    }
    
    func showArticle(article: Article) {
        println("Show \(article.title)")
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

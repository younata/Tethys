//
//  FeedsTableViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/29/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class FeedsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MAKDropDownMenuDelegate, UITextFieldDelegate {

    var feeds: [Feed] = []
    
    let tableViewController = UITableViewController(style: .Plain)
    
    var tableView : UITableView {
        return self.tableViewController.tableView
    }
    
    let dropDownMenu = MAKDropDownMenu(forAutoLayout: ())
    let tagField = UITextField(forAutoLayout: ())
    var menuTopOffset : NSLayoutConstraint!
    
    var dataManager : DataManager? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
                
        self.addChildViewController(tableViewController)
        self.view.addSubview(tableView)
        tableView.setTranslatesAutoresizingMaskIntoConstraints(false)
        tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        
        tagField.placeholder = NSLocalizedString("Filter by Tag", comment: "")
        tagField.delegate = self
        tagField.backgroundColor = UIColor.whiteColor()
        
        self.view.addSubview(dropDownMenu)
        dropDownMenu.delegate = self
        dropDownMenu.separatorHeight = 1.0 / UIScreen.mainScreen().scale
        dropDownMenu.buttonsInsets = UIEdgeInsetsMake(dropDownMenu.separatorHeight, 0, 0, 0)
        dropDownMenu.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        dropDownMenu.tintColor = UIColor.darkGreenColor()
        dropDownMenu.backgroundColor = UIColor(white: 0.75, alpha: 0.5)
        menuTopOffset = dropDownMenu.autoPinEdgeToSuperviewEdge(.Top)
        dropDownMenu.hidden = true

        self.tableView.registerClass(FeedTableCell.self, forCellReuseIdentifier: "cell")
        self.tableView.delegate = self
        self.tableView.dataSource = self;

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "addFeed")
        self.navigationItem.rightBarButtonItems = [addButton, tableViewController.editButtonItem()]
        self.navigationItem.title = NSLocalizedString("Feeds", comment: "")
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 80
        
        self.tableViewController.refreshControl = UIRefreshControl(frame: CGRectZero)
        self.tableViewController.refreshControl?.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
        
        self.tableView.tableFooterView = UIView()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reload", name: "UpdatedFeed", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "appWillBecomeVisible:", name: UIApplicationWillEnterForegroundNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        super.willRotateToInterfaceOrientation(toInterfaceOrientation, duration: duration)
        let landscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation)
        let statusBarHeight : CGFloat = (landscape ? 0 : 20)
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            let navBarHeight : CGFloat = (landscape ? 32 : 44)
            menuTopOffset.constant = navBarHeight + statusBarHeight
        } else {
            menuTopOffset.constant = 44 + statusBarHeight
        }
        UIView.animateWithDuration(duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.reload()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        if let rc = self.tableViewController.refreshControl {
            if rc.refreshing {
                rc.endRefreshing()
            }
        }
    }
    
    func showSettings() {
        let settings = UINavigationController(rootViewController: UIViewController())
        // TODO: Settings
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            let popover = UIPopoverController(contentViewController: settings)
            popover.popoverContentSize = CGSizeMake(600, 800)
            popover.presentPopoverFromBarButtonItem(navigationItem.leftBarButtonItem!, permittedArrowDirections: .Any, animated: true)
        } else {
            presentViewController(settings, animated: true, completion: nil)
        }
    }
    
    func addFeed() {
        if (self.navigationController!.visibleViewController != self) {
            return
        }

        dropDownMenu.titles = [NSLocalizedString("Add from Web", comment: ""), NSLocalizedString("Add from Local", comment: ""), NSLocalizedString("Create Query Feed", comment: "")]
        menuTopOffset.constant = CGRectGetHeight(self.navigationController!.navigationBar.frame) + (UIApplication.sharedApplication().statusBarHidden ? 0 : 20)
        if dropDownMenu.isOpen {
            dropDownMenu.closeAnimated(true)
        } else {
            dropDownMenu.openAnimated(true)
        }
    }
    
    func dropDownMenu(menu: MAKDropDownMenu!, itemDidSelect itemIndex: UInt) {
        var vc : UINavigationController? = nil
        if itemIndex == 0 {
            let findFeed = FindFeedViewController()
            findFeed.dataManager = dataManager
            vc = UINavigationController(rootViewController: findFeed)
        } else if itemIndex == 1 {
            let localImport = LocalImportViewController()
            localImport.dataManager = dataManager
            vc = UINavigationController(rootViewController: localImport)
        } else if itemIndex == 2 {
            let queryFeed = QueryFeedViewController(style: .Grouped)
            queryFeed.dataManager = dataManager
            queryFeed.feed = dataManager?.newFeed()
            vc = UINavigationController(rootViewController: queryFeed)
        }
        if let nc = vc {
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: nc)
                popover.popoverContentSize = CGSizeMake(600, 800)
                popover.presentPopoverFromBarButtonItem(self.navigationItem.rightBarButtonItem!, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(nc, animated: true, completion: nil)
            }
        }
        menu.closeAnimated(true)
    }
    
    func dropDownMenuDidTapOutsideOfItem(menu: MAKDropDownMenu!) {
        menu.closeAnimated(true)
    }
    
    func reload() {
        reload(nil)
    }
    
    func reload(tag: String?) {
        let oldFeeds = feeds
        feeds = dataManager!.feedsMatchingTag(tag).sorted {(f1: Feed, f2: Feed) in
            let f1Unread = f1.unreadArticles(self.dataManager!)
            let f2Unread = f2.unreadArticles(self.dataManager!)
            if f1Unread != f2Unread {
                return f1Unread > f2Unread
            }
            if f1.feedTitle() == nil {
                return true
            } else if f2.feedTitle() == nil {
                return false
            }
            return f1.feedTitle()!.lowercaseString < f2.feedTitle()!.lowercaseString
        }
        if let rc = self.tableViewController.refreshControl {
            if rc.refreshing {
                rc.endRefreshing()
            }
        }
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }
    
    func appWillBecomeVisible(note: NSNotification) {
        dispatch_async(dispatch_get_main_queue()) {
            if let rc = self.tableViewController.refreshControl {
                rc.beginRefreshing()
                let contentOffset = self.tableViewController.tableView.contentOffset.y - (rc.frame.size.height + (UIApplication.sharedApplication().statusBarHidden ? 0 : 20))
                self.tableViewController.tableView.setContentOffset(CGPointMake(0, contentOffset), animated: true)
            }
            self.refresh()
        }
    }
    
    func refresh() {
        dataManager!.updateFeeds({(_) in
            self.reload()
        })
    }
    
    func feedAtIndexPath(indexPath: NSIndexPath) -> Feed! {
        return feeds[indexPath.row]
    }
    
    func showFeeds(feeds: [Feed]) -> ArticleListController {
        return showFeeds(feeds, animated: true)
    }
    
    func showFeeds(feeds: [Feed], animated: Bool) -> ArticleListController {
        let al = ArticleListController(style: .Plain)
        al.dataManager = dataManager
        al.feeds = feeds
        self.navigationController?.pushViewController(al, animated: animated)
        return al
    }

    // MARK: - Table view data source
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            return tagField
        }
        return nil
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feeds.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as FeedTableCell
        cell.dataManager = dataManager
        cell.feed = feedAtIndexPath(indexPath)
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        showFeeds([feedAtIndexPath(indexPath)])
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Delete", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
            let feed = self.feedAtIndexPath(indexPath)
            self.dataManager!.deleteFeed(feed)
            self.reload()
        })
        let markRead = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Mark\nRead", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
            let feed = self.feedAtIndexPath(indexPath)
            for article in feed.allArticles(self.dataManager!) {
                article.read = true
            }
            self.dataManager!.saveContext()
            self.reload()
        })
        let edit = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Edit", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
            let feed = self.feedAtIndexPath(indexPath)
            var viewController : UIViewController? = nil
            if feed.isQueryFeed() {
                let vc = QueryFeedViewController(style: .Grouped)
                vc.feed = feed
                vc.dataManager = self.dataManager
                viewController = vc
            } else {
                let vc = FeedViewController(style: .Grouped)
                vc.feed = feed
                vc.dataManager = self.dataManager
                viewController = vc
            }
            if let vc = viewController {
                self.presentViewController(UINavigationController(rootViewController: vc), animated: true, completion: nil)
            }
        })
        edit.backgroundColor = UIColor.blueColor()
        return [delete, markRead, edit]
    }
    
    // MARK: UITextFieldDelegate
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let text = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)
        self.reload(text)
        return true
    }
}

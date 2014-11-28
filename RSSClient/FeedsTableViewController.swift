//
//  FeedsTableViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/29/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class FeedsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MAKDropDownMenuDelegate {

    var feeds: [Feed] = []
    
    let tableViewController = UITableViewController(style: .Plain)
    
    var tableView : UITableView {
        return self.tableViewController.tableView
    }
    
    let dropDownMenu = MAKDropDownMenu(forAutoLayout: ())
    var menuTopOffset : NSLayoutConstraint!
    
    var dataManager : DataManager? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addChildViewController(tableViewController)
        self.view.addSubview(tableView)
        tableView.setTranslatesAutoresizingMaskIntoConstraints(false)
        tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        
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
        self.tableViewController.refreshControl?.beginRefreshing()
        self.refresh()
        self.tableViewController.refreshControl?.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
        
        self.tableView.tableFooterView = UIView()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reload", name: "UpdatedFeed", object: nil)
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

        dropDownMenu.titles = [NSLocalizedString("Add from Web", comment: ""), NSLocalizedString("Add from Local", comment: "")]
        menuTopOffset.constant = CGRectGetHeight(self.navigationController!.navigationBar.frame) + (UIApplication.sharedApplication().statusBarHidden ? 0 : 20)
        if dropDownMenu.isOpen {
            dropDownMenu.closeAnimated(true)
        } else {
            dropDownMenu.openAnimated(true)
        }
    }
    
    func dropDownMenu(menu: MAKDropDownMenu!, itemDidSelect itemIndex: UInt) {
        if itemIndex == 0 {
            let findFeed = FindFeedViewController()
            findFeed.dataManager = dataManager
            let vc = UINavigationController(rootViewController: findFeed)
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: vc)
                popover.popoverContentSize = CGSizeMake(600, 800)
                popover.presentPopoverFromBarButtonItem(self.navigationItem.rightBarButtonItem!, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(vc, animated: true, completion: nil)
            }
        } else if itemIndex == 1 {
            let localImport = LocalImportViewController()
            localImport.dataManager = dataManager
            let vc = UINavigationController(rootViewController: localImport)
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: vc)
                popover.popoverContentSize = CGSizeMake(600, 800)
                popover.presentPopoverFromBarButtonItem(self.navigationItem.rightBarButtonItem!, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(vc, animated: true, completion: nil)
            }
        }
        menu.closeAnimated(true)
    }
    
    func dropDownMenuDidTapOutsideOfItem(menu: MAKDropDownMenu!) {
        menu.closeAnimated(true)
    }
    
    func reload() {
        let oldFeeds = feeds
        feeds = dataManager!.feeds().sorted {(f1: Feed, f2: Feed) in
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
        }
        if feeds.count == 0 {
            self.tableViewController.refreshControl?.endRefreshing()
        }
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }
    
    func appDidBecomeVisible(note: NSNotification) {
        self.tableViewController.refreshControl?.beginRefreshing()
        self.refresh()
    }
    
    func refresh() {
        dataManager!.updateFeeds({(_) in
            self.tableViewController.refreshControl?.endRefreshing()
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

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feeds.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as FeedTableCell
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
            for article in feed.articles.allObjects as [Article] {
                article.read = true
            }
            self.dataManager!.saveContext()
            self.reload()
        })
        return [delete, markRead]
    }
}

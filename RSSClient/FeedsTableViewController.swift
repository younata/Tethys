//
//  FeedsTableViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/29/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class FeedsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MAKDropDownMenuDelegate, UITextFieldDelegate, UISearchBarDelegate, BreakOutToRefreshDelegate {

    var feeds: [Feed] = []
    
    let tableViewController = UITableViewController(style: .Plain)
    
    var tableView : UITableView {
        return self.tableViewController.tableView
    }
    
    let dropDownMenu = MAKDropDownMenu(forAutoLayout: ())
    let searchBar = UISearchBar(frame: CGRectMake(0, 0, 320, 32))
    
    var menuTopOffset : NSLayoutConstraint!
    
    lazy var refreshView : BreakOutToRefreshView = {
        let refreshView = BreakOutToRefreshView(scrollView: self.tableView)
        refreshView.delegate = self
        refreshView.scenebackgroundColor = UIColor(hue: 0.68, saturation: 0.9, brightness: 0.3, alpha: 1.0)
        refreshView.paddleColor = UIColor.lightGrayColor()
        refreshView.ballColor = UIColor.whiteColor()
        refreshView.blockColors = [UIColor(hue: 0.17, saturation: 0.9, brightness: 1.0, alpha: 1.0),
                                   UIColor(hue: 0.17, saturation: 0.7, brightness: 1.0, alpha: 1.0),
                                   UIColor(hue: 0.17, saturation: 0.5, brightness: 1.0, alpha: 1.0)]
        return refreshView
    }()
    
    lazy var dataManager : DataManager = { self.injector!.create(DataManager.self) as DataManager }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addChildViewController(tableViewController)
        self.view.addSubview(tableView)
        tableView.setTranslatesAutoresizingMaskIntoConstraints(false)
        tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        
        tableView.tableHeaderView = searchBar
        
        searchBar.autocorrectionType = .No
        searchBar.autocapitalizationType = .None
        searchBar.delegate = self
        searchBar.placeholder = NSLocalizedString("Filter by Tag", comment: "")
        
        self.view.addSubview(dropDownMenu)
        dropDownMenu.delegate = self
        dropDownMenu.separatorHeight = 1.0 / UIScreen.mainScreen().scale
        dropDownMenu.buttonsInsets = UIEdgeInsetsMake(dropDownMenu.separatorHeight, 0, 0, 0)
        dropDownMenu.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        dropDownMenu.tintColor = UIColor.darkGreenColor()
        dropDownMenu.backgroundColor = UIColor(white: 0.75, alpha: 0.5)
        menuTopOffset = dropDownMenu.autoPinEdgeToSuperviewEdge(.Top)
        dropDownMenu.hidden = true

        self.tableView.registerClass(FeedTableCell.self, forCellReuseIdentifier: "read")
        self.tableView.registerClass(FeedTableCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on whether new feed loaded into it has unread articles or not.
        self.tableView.delegate = self
        self.tableView.dataSource = self;

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "addFeed")
        self.navigationItem.rightBarButtonItems = [addButton, tableViewController.editButtonItem()]
        self.navigationItem.title = NSLocalizedString("Feeds", comment: "")
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 80
        
        self.tableView.addSubview(self.refreshView)
        
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
        var klass : AnyClass! = nil
        if itemIndex == 0 {
            klass = FindFeedViewController.self
        } else if itemIndex == 1 {
            klass = LocalImportViewController.self
        } else if itemIndex == 2 {
            klass = QueryFeedViewController.self
        } else {
            menu.closeAnimated(true)
            return
        }
        let nc = UINavigationController(rootViewController: self.injector!.create(klass) as UIViewController)
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            let popover = UIPopoverController(contentViewController: nc)
            popover.popoverContentSize = CGSizeMake(600, 800)
            popover.presentPopoverFromBarButtonItem(self.navigationItem.rightBarButtonItem!, permittedArrowDirections: .Any, animated: true)
        } else {
            self.presentViewController(nc, animated: true, completion: nil)
        }
        menu.closeAnimated(true)
    }
    
    func dropDownMenuDidTapOutsideOfItem(menu: MAKDropDownMenu!) {
        menu.closeAnimated(true)
    }
    
    func reload(_ tag: String? = nil) {
        let oldFeeds = feeds
        feeds = dataManager.feedsMatchingTag(tag).sorted {(f1: Feed, f2: Feed) in
            let f1Unread = f1.unreadArticles(self.dataManager)
            let f2Unread = f2.unreadArticles(self.dataManager)
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
    
    func refresh() {
        dataManager.updateFeeds({(_) in
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
    
    // MARK: - BreakOutToRefreshDelegate
    
    func refreshViewDidRefresh(refreshView: BreakOutToRefreshView) {
        reload(nil)
    }
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        self.searchBar.resignFirstResponder()
    }

    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feeds.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let feed = feedAtIndexPath(indexPath)
        let strToUse = (feed.unreadArticles(self.dataManager) == 0 ? "unread" : "read") // Prevents a green triangle which'll (dis)appear depending on whether new feed loaded into it has unread articles or not.
        
        let cell = tableView.dequeueReusableCellWithIdentifier(strToUse, forIndexPath: indexPath) as FeedTableCell
        cell.dataManager = dataManager
        cell.feed = feed
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
            self.dataManager.deleteFeed(feed)
            self.reload()
        })
        let markRead = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Mark\nRead", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
            let feed = self.feedAtIndexPath(indexPath)
            self.dataManager.readArticles(feed.allArticles(self.dataManager))
            self.reload()
        })
        let edit = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Edit", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
            let feed = self.feedAtIndexPath(indexPath)
            var klass : AnyClass? = nil
            var viewController : UIViewController! = nil
            if feed.isQueryFeed() {
                let vc = self.injector!.create(QueryFeedViewController.self) as QueryFeedViewController
                vc.feed = feed
                viewController = vc
            } else {
                let vc = self.injector!.create(FeedViewController.self) as FeedViewController
                vc.feed = feed
                viewController = vc
            }
            self.presentViewController(UINavigationController(rootViewController: viewController), animated: true, completion: nil)
        })
        edit.backgroundColor = UIColor.blueColor()
        return [delete, markRead, edit]
    }
    
    // MARK: UISearchBarDelegate
    
    func searchBar(searchBar: UISearchBar, textDidChange text: String) {
        self.reload(text)
    }
}

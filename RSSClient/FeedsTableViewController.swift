//
//  FeedsTableViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/29/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class FeedsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITabBarDelegate, MAKDropDownMenuDelegate {
    
    enum DisplayState {
        case feeds
        case groups
    }
    
    var groups: [Group] = []
    var feeds: [Feed] = []
    var state: DisplayState = .feeds
    
    let tabBar = UITabBar(forAutoLayout: ())
    
    let tableViewController = UITableViewController(style: .Plain)
    
    var tableView : UITableView {
        return self.tableViewController.tableView
    }
    
    var feedsTabItem: UITabBarItem! = nil
    var groupsTabItem: UITabBarItem! = nil
    
    let dropDownMenu = MAKDropDownMenu(forAutoLayout: ())
    var menuTopOffset : NSLayoutConstraint!

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
        menuTopOffset = dropDownMenu.autoPinEdgeToSuperviewEdge(.Top)
        
        /*
        self.view.addSubview(tabBar)
        tabBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        tabBar.autoSetDimension(.Height, toSize: 44)
        */ // I don't want to deal with assets for feeds and groups.
        feedsTabItem = UITabBarItem(title: NSLocalizedString("Feeds", comment: ""), image: nil, selectedImage: nil) // TODO: images
        groupsTabItem = UITabBarItem(title: NSLocalizedString("Groups", comment: ""), image: nil, selectedImage: nil)
        tabBar.items = [feedsTabItem, groupsTabItem]
        tabBar.selectedItem = feedsTabItem
        tabBar.delegate = self

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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "appDidBecomeVisible", name: UIApplicationWillEnterForegroundNotification, object: nil)
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
    
    func tabBar(tabBar: UITabBar, didSelectItem item: UITabBarItem!) {
        if (item == feedsTabItem) {
            state = .feeds
        } else if (item == groupsTabItem) {
            state = .groups
        }
        reload()
    }
    
    func addFeed() {
        if (self.navigationController!.visibleViewController != self) {
            return
        }
        
        switch (state) {
        case .feeds:
            dropDownMenu.titles = [NSLocalizedString("Add from Web", comment: ""), NSLocalizedString("Add from Local", comment: "")]
            menuTopOffset.constant = CGRectGetHeight(self.navigationController!.navigationBar.frame) + (UIApplication.sharedApplication().statusBarHidden ? 0 : 20)
            if dropDownMenu.isOpen {
                dropDownMenu.closeAnimated(true)
            } else {
                dropDownMenu.openAnimated(true)
            }
        case .groups:
            let alert = UIAlertController(title: NSLocalizedString("New Group", comment: ""),
                message: nil,
                preferredStyle: .Alert)
            alert.addTextFieldWithConfigurationHandler({(textField: UITextField!) in
                print("")
                textField.becomeFirstResponder()
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: UIAlertActionStyle.Cancel, handler: {(_) in
                print("") // really?
                alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Create Group", comment: ""), style: .Default, handler: {(_) in
                if let textField = alert.textFields?.last as? UITextField {
                    let groupName = textField.text
                    
                    if (groupName as NSString).length > 0 {
                        if !contains(self.groups.map({return $0.name}), groupName) {
                            let group = DataManager.sharedInstance().newGroup(groupName)
                            self.reload()
                            alert.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
                        } else {
                            alert.message = NSLocalizedString("Group name must be unique", comment: "")
                        }
                    } else {
                        alert.message = NSLocalizedString("Group must be named", comment: "")
                    }
                    
                } else {
                    fatalError("add group alert presented without a configured textfield")
                }
            }))
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func dropDownMenu(menu: MAKDropDownMenu!, itemDidSelect itemIndex: UInt) {
        if itemIndex == 0 {
            let vc = UINavigationController(rootViewController: FindFeedViewController())
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: vc)
                popover.popoverContentSize = CGSizeMake(600, 800)
                popover.presentPopoverFromBarButtonItem(self.navigationItem.rightBarButtonItem!, permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(vc, animated: true, completion: nil)
            }
        } else if itemIndex == 1 {
            let vc = UINavigationController(rootViewController: LocalImportViewController())
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
        feeds = DataManager.sharedInstance().feeds().sorted {(f1: Feed, f2: Feed) in
            let f1Unread = f1.unreadArticles()
            let f2Unread = f2.unreadArticles()
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
        groups = DataManager.sharedInstance().groups()
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }
    
    func appDidBecomeVisible(note: NSNotification) {
        self.tableViewController.refreshControl?.beginRefreshing()
        self.refresh()
    }
    
    func refresh() {
        DataManager.sharedInstance().updateFeeds({(_) in
            self.tableViewController.refreshControl?.endRefreshing()
            self.reload()
        })
    }
    
    func groupAtIndexPath(indexPath: NSIndexPath) -> Group? {
        switch (state) {
        case .feeds:
            return nil
        case .groups:
            return groups[indexPath.row]
        }
    }
    
    func feedAtIndexPath(indexPath: NSIndexPath) -> Feed! {
        switch (state) {
        case .feeds:
            return feeds[indexPath.row]
        case .groups:
            if let feedSet = groupAtIndexPath(indexPath)?.feeds {
                let feedArray = (feedSet.allObjects as [Feed])
                let sortedArray = feedArray.sorted { return $0.title < $1.title }
                return sortedArray.last
            }
        }
        return nil
    }
    
    func showFeeds(feeds: [Feed]) -> ArticleListController {
        return showFeeds(feeds, animated: true)
    }
    
    func showFeeds(feeds: [Feed], animated: Bool) -> ArticleListController {
        let al = ArticleListController(style: .Plain)
        al.feeds = feeds
        self.navigationController?.pushViewController(al, animated: animated)
        return al
    }

    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (state) {
        case .feeds:
            return feeds.count
        case .groups:
            return groups.count
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        switch (state) {
        case .feeds:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as FeedTableCell
            cell.feed = feedAtIndexPath(indexPath)
            return cell
        case .groups:
            let cell = tableView.dequeueReusableCellWithIdentifier("groups", forIndexPath: indexPath) as UITableViewCell
            cell.textLabel?.text = self.groupAtIndexPath(indexPath)!.name
            return cell
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        
        switch (state) {
        case .feeds:
            showFeeds([feedAtIndexPath(indexPath)])
        case .groups:
            showFeeds((groupAtIndexPath(indexPath)!.feeds.allObjects as [Feed]).sorted {return $0.title < $1.title})
        }
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Delete", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
            switch (self.state) {
            case .feeds:
                let feed = self.feedAtIndexPath(indexPath)
                DataManager.sharedInstance().deleteFeed(feed)
                self.reload()
            case .groups:
                let group = self.groupAtIndexPath(indexPath)!
                DataManager.sharedInstance().deleteGroup(self.groupAtIndexPath(indexPath)!)
                self.reload()
            }
        })
        switch (self.state) {
        case .feeds:
            let markRead = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Mark\nRead", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
                let feed = self.feedAtIndexPath(indexPath)
                for article in feed.articles.allObjects as [Article] {
                    article.read = true
                }
                DataManager.sharedInstance().saveContext()
                self.reload()
            })
            return [delete, markRead]
        case .groups:
            let edit = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Edit", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
                let gvc = GroupsEditorController()
                gvc.group = self.groupAtIndexPath(indexPath)
                self.tableView.setEditing(false, animated: true)
                self.presentViewController(UINavigationController(rootViewController: gvc), animated: true, completion: nil)
            })
            return [delete, edit]
        }
    }
}

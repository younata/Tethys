//
//  FeedsTableViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/29/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class FeedsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITabBarDelegate {
    
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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addChildViewController(tableViewController)
        self.view.addSubview(tableView)
        tableView.setTranslatesAutoresizingMaskIntoConstraints(false)
        tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        
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

        self.tableViewController.refreshControl = UIRefreshControl(frame: CGRectZero)
        self.tableViewController.refreshControl?.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
        
        self.tableView.registerClass(FeedTableCell.self, forCellReuseIdentifier: "cell")
        self.tableView.delegate = self
        self.tableView.dataSource = self;

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "addFeed")
        self.navigationItem.rightBarButtonItems = [addButton, tableViewController.editButtonItem()]
        self.navigationItem.title = NSLocalizedString("Feeds", comment: "")
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 80
        self.refresh()
        self.tableViewController.refreshControl?.beginRefreshing()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reload", name: "UpdatedFeed", object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.reload()
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
        
        var controller = UIViewController()
        switch (state) {
        case .feeds:
            controller = FindFeedViewController()
        case .groups:
            let alert = UIAlertController(title: NSLocalizedString("New Group", comment: ""),
                                        message: nil,
                                 preferredStyle: .Alert)
            alert.addTextFieldWithConfigurationHandler({(textField: UITextField!) in
                // TODO: configure this textfield?
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
            controller = alert
        }
        let vc = UINavigationController(rootViewController: controller)
        self.presentViewController(vc, animated: true, completion: nil)
    }
    
    func reload() {
        feeds = DataManager.sharedInstance().feeds()
        groups = DataManager.sharedInstance().groups()
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }
    
    func refresh() {
        self.tableViewController.refreshControl?.endRefreshing()
        self.reload()
        DataManager.sharedInstance().updateFeeds({
            if $0 == nil {
                self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
            } else {
                // TODO: alert the user
            }
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
            cell.textLabel.text = self.groupAtIndexPath(indexPath)!.name
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
                DataManager.sharedInstance().deleteFeed(self.feedAtIndexPath(indexPath))
            case .groups:
                DataManager.sharedInstance().deleteGroup(self.groupAtIndexPath(indexPath)!)
            }
            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        })
        switch (self.state) {
        case .feeds:
            let markRead = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Mark\nRead", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
                let feed = self.feedAtIndexPath(indexPath)
                for article in feed.articles.allObjects as [Article] {
                    article.read = true
                }
                self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                DataManager.sharedInstance().saveContext()
            })
            return [delete, markRead]
        case .groups:
            let edit = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Edit", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
                let gvc = GroupsEditorController()
                gvc.group = self.groupAtIndexPath(indexPath)
                self.presentViewController(UINavigationController(rootViewController: gvc), animated: true, completion: nil)
            })
            return [delete, edit]
        }
    }
}

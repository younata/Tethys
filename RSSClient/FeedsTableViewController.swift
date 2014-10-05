//
//  FeedsTableViewController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/29/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class FeedsTableViewController: UITableViewController {
    
    enum DisplayState {
        case feeds
        case groups
    }
    
    var groups: [Group] = []
    var feeds: [Feed] = []
    var state: DisplayState = .feeds

    override func viewDidLoad() {
        super.viewDidLoad()

        self.refreshControl = UIRefreshControl(frame: CGRectZero)
        self.refreshControl?.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
        
        self.tableView.registerClass(FeedTableCell.self, forCellReuseIdentifier: "cell")

        let addButton = UIBarButtonItem(title: "Add", style: .Plain, target: self, action: "addFeed")
        self.navigationItem.rightBarButtonItems = [addButton, self.editButtonItem()]
        self.navigationItem.title = NSLocalizedString("Feeds", comment: "")
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 80
        self.refresh()
        
        //self.toolbarItems = []
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reload", name: "UpdatedFeed", object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.reload()
    }
    
    func addFeed() {
        if (self.navigationController!.visibleViewController != self) {
            return
        }
        
        let vc = UINavigationController(rootViewController: FindFeedViewController())
        self.presentViewController(vc, animated: true, completion: nil)
    }
    
    func reload() {
        feeds = DataManager.sharedInstance().feeds()
        groups = DataManager.sharedInstance().groups()
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }
    
    func refresh() {
        self.refreshControl?.endRefreshing()
        self.reload()
        DataManager.sharedInstance().updateFeeds({
            self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
        })
    }
    
    func groupAtSection(section: Int) -> Group? {
        if section > 0 && (section - 1) < groups.count {
            return groups[section-1]
        }
        return nil
    }
    
    func feedAtIndexPath(indexPath: NSIndexPath) -> Feed! {
        if indexPath.section == 0 {
            return feeds[indexPath.row]
        }
        if let feedSet = groupAtSection(indexPath.section)?.feeds {
            let feedArray = (feedSet.allObjects as [Feed])
            let sortedArray = feedArray.sorted { return $0.title < $1.title }
            return sortedArray.last
        }
        return nil
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        switch (self.state) {
        case .feeds:
            return 1
        case .groups:
            return 1 + groups.count
        }
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? feeds.count : self.groupAtSection(section)!.feeds.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as FeedTableCell
        
        cell.feed = feedAtIndexPath(indexPath)

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        
        let al = ArticleListController(style: .Plain)
        al.feeds = [feedAtIndexPath(indexPath)]
        self.navigationController?.pushViewController(al, animated: true)
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        switch (self.state) {
        case .feeds:
            return true
        case .groups:
            return indexPath.section != 0
        }
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch (self.state) {
        case .feeds:
            return nil
        case .groups:
            if section == 0 {
                return NSLocalizedString("All", comment: "")
            } else if let group = self.groupAtSection(section) {
                return group.name
            }
        }
        return nil
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let markRead = UITableViewRowAction(style: .Normal, title: NSLocalizedString("Mark Read", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
            let feed = self.feedAtIndexPath(indexPath)
            for article in feed.articles.allObjects as [Article] {
                article.read = true
            }
            self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        })
        switch (self.state) {
        case .feeds:
            let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Delete", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
                let feed = self.feedAtIndexPath(indexPath)
                DataManager.sharedInstance().deleteFeed(feed)
                self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            })
            return [delete, markRead]
        case .groups:
            let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Remove", comment: ""), handler: {(_, indexPath: NSIndexPath!) in
                let feed = self.feedAtIndexPath(indexPath)
                if let group = self.groupAtSection(indexPath.section) {
                    feed.removeGroupsObject(group)
                    group.removeFeedsObject(feed)
                    self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                }
            })
            return [delete, markRead]
        }
    }
}

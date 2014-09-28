//
//  ArticleListController.swift
//  RSSClient
//
//  Created by Rachel Brindle on 9/27/14.
//  Copyright (c) 2014 Rachel Brindle. All rights reserved.
//

import UIKit

class ArticleListController: UITableViewController {
    
    var articles : [Article] = []
    var feeds : [Feed] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "reuse")
        
        self.refreshControl = UIRefreshControl(frame: CGRectZero)
        self.refreshControl?.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
    }
    
    func articleForIndexPath(indexPath: NSIndexPath) -> Article {
        return articles[indexPath.row]
    }
    
    func refresh() {
        articles = []
        for f in fs {
            articles += (f.articles.allObjects as [Article])
        }
        articles.sort({(a : Article, b: Article) in
            var da : NSDate = a.updatedAt ?? a.published
            var db : NSDate = b.updatedAt ?? b.published
            return (da as NSDate) < (db as NSDate)
        })
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
        self.refreshControl?.endRefreshing()
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuse", forIndexPath: indexPath) as ArticleCell
        
        cell.article = articleForIndexPath(indexPath)

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        
        let avc = ArticleViewController()
        let article = self.articleForIndexPath(indexPath)
        avc.article = article
        self.navigationController?.pushViewController(avc, animated: true)
        article.read = true
        article.managedObjectContext.save(nil)
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let article = self.articleForIndexPath(indexPath)
        let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Delete", comment: ""), handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
            DataManager.sharedInstance().managedObjectContext.deleteObject(article)
            article.managedObjectContext.save(nil)
            self.refresh()
        })
        let unread = NSLocalizedString("Mark as unread", comment: "")
        let read = NSLocalizedString("Mark as read", comment: "")
        let toggleRead = UITableViewRowAction(style: .Normal, title: article.read ? unread : read, handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
            article.read = !article.read
            article.managedObjectContext.save(nil)
            tableView.reloadSections(NSIndexSet(index: indexPath.section), withRowAnimation: .Automatic)
        })
    }
}

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
    let queue = dispatch_queue_create("articleController", nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "reuse")
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        
        self.refreshControl = UIRefreshControl(frame: CGRectZero)
        self.refreshControl?.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
        self.refreshControl?.beginRefreshing()
    }
    
    override func viewDidAppear(animated: Bool) {
        self.refreshControl?.beginRefreshing()
        refresh()
        if feeds.count == 1 {
            self.navigationItem.title = feeds.first?.title
        }
    }
    
    func articleForIndexPath(indexPath: NSIndexPath) -> Article {
        return articles[indexPath.row]
    }
    
    func refresh() {
        dispatch_async(queue) {
            let articles = self.feeds.reduce([]) { return $0 + $1.articles.allObjects }
            let newArticles = NSSet(array: articles)
            let oldArticles = NSSet(array: self.articles)
            if newArticles != oldArticles {
                self.articles = (articles as [Article])
                self.articles.sort({(a : Article, b: Article) in
                    let da = a.updatedAt ?? a.published
                    let db = b.updatedAt ?? b.published
                    return da!.timeIntervalSince1970 > db!.timeIntervalSince1970
                })
            }
            dispatch_async(dispatch_get_main_queue()) {
                if newArticles != oldArticles {
                    self.tableView.reloadData()
                }
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    func showArticle(article: Article) -> ArticleViewController {
        return showArticle(article, animated: true)
    }
    
    func showArticle(article: Article, animated: Bool) -> ArticleViewController {
        var avc : ArticleViewController
        if let splitView = self.splitViewController {
            avc = (splitView.viewControllers.last as ArticleViewController)
        } else {
            avc = ArticleViewController()
            self.navigationController?.pushViewController(avc, animated: animated)
        }
        avc.article = article
        avc.articles = self.articles//.filter { return !$0.read }
        avc.lastArticleIndex = 0
        return avc
    }
    
    // MARK: - Scroll view delegate
    
    // infinite scrolling, is it worth it?
    /*
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        let actualPosition = scrollView.contentOffset.y;
        let contentHeight = scrollView.contentSize.height - (10 * self.tableView.estimatedRowHeight)
        let maxIndexPath = (self.tableView.indexPathsForVisibleRows() as [NSIndexPath]).reduce(NSIndexPath(forRow: 0, inSection: 0), combine: {
            if $0.row < $1.row {
                return $1
            }
            return $0
        })
        if (actualPosition >= contentHeight) {
            // try to load more...
            self.articles += 
            self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .None)
        }
    }
    */

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
    }
    
    override func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let article = articleForIndexPath(indexPath)
        
        if article.content == nil {
            return 30
        }
        return 100
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuse", forIndexPath: indexPath) as ArticleCell
        
        cell.article = articleForIndexPath(indexPath)

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        
        showArticle(articleForIndexPath(indexPath))
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let article = self.articleForIndexPath(indexPath)
        let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Delete", comment: ""), handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
            DataManager.sharedInstance().managedObjectContext.deleteObject(article)
            article.managedObjectContext?.save(nil)
            self.refresh()
        })
        let unread = NSLocalizedString("Mark\nUnread", comment: "")
        let read = NSLocalizedString("Mark\nRead", comment: "")
        let toggleText = article.read ? unread : read
        let toggle = UITableViewRowAction(style: .Normal, title: toggleText, handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
            article.read = !article.read
            article.managedObjectContext?.save(nil)
            tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
        })
        return [delete, toggle]
    }
}

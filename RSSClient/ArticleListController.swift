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
    var feeds : [Feed]? = nil
    let queue = dispatch_queue_create("articleController", nil)
    
    var dataManager : DataManager? = nil
    
    var previewMode : Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "reuse")
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        
        self.tableView.tableFooterView = UIView()
        
        if !previewMode {
            self.refreshControl = UIRefreshControl(frame: CGRectZero)
            self.refreshControl?.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
            self.refreshControl?.beginRefreshing()
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "articleRead:", name: "ArticleWasRead", object: nil)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func articleRead(note: NSNotification) {
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if !previewMode {
            self.refreshControl?.beginRefreshing()
            refresh()
            if feeds?.count == 1 {
                self.navigationItem.title = feeds?.first?.title
            }
        }
    }
    
    func articleForIndexPath(indexPath: NSIndexPath) -> Article {
        return articles[indexPath.row]
    }
    
    func refresh() {
        if let feeds = self.feeds {
            dispatch_async(queue) {
                let articles = feeds.reduce([] as [Article]) { return $0 + $1.allArticles(self.dataManager!) }
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
        } else {
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
    }
    
    func showArticle(article: Article) -> ArticleViewController {
        return showArticle(article, animated: true)
    }
    
    func showArticle(article: Article, animated: Bool) -> ArticleViewController {
        let avc = self.splitViewController?.viewControllers.last as? ArticleViewController ?? ArticleViewController()
        avc.article = article
        avc.articles = self.articles
        if (self.articles.count != 0) {
            avc.lastArticleIndex = (self.articles as NSArray).indexOfObject(article)
        } else {
            avc.lastArticleIndex = 0
        }
        if let splitView = self.splitViewController {
            (UIApplication.sharedApplication().delegate as AppDelegate).collapseDetailViewController = false
            splitView.showDetailViewController(UINavigationController(rootViewController: avc), sender: self)
        } else {
            self.navigationController?.pushViewController(avc, animated: animated)
        }
        return avc
    }
    
    // MARK: - Scroll view delegate
    
    // infinite scrolling, is it worth it? (Yes, but later)
    // TODO: infinite scrolling
    /*
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        let actualPosition = scrollView.contentOffset.y;
        let contentHeight = scrollView.contentSize.height - (10 * self.tableView.estimatedRowHeight)
        let maxIndexPath = (self.tableView.indexPathsForVisibleRows() as [NSIndexPath]).reduce(NSIndexPath(forRow: 0, inSection: 0)) {
            if $0.row < $1.row {
                return $1
            }
            return $0
        }
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
        
        if !previewMode {
            showArticle(articleForIndexPath(indexPath))
        }
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        if previewMode {
            return nil
        }
        let article = self.articleForIndexPath(indexPath)
        let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Delete", comment: ""), handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
            article.managedObjectContext?.deleteObject(article)
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

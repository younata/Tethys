import UIKit

public class ArticleListController: UITableViewController {

    var articles: [Article] = []
    public var feeds: [Feed]? = nil
    let queue = dispatch_queue_create("articleController", nil)

    var dataManager: DataManager? = nil

    public var previewMode: Bool = false

    lazy var mainQueue: NSOperationQueue! = {
        self.injector!.create(kMainQueue) as! NSOperationQueue
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = self.editButtonItem()

        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "read")
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on whether
        // article loaded into it is read or not.

        self.tableView.rowHeight = UITableViewAutomaticDimension

        self.tableView.tableFooterView = UIView()

        if !previewMode {
            self.refreshControl = UIRefreshControl(frame: CGRectZero)
            self.refreshControl?.addTarget(self, action: "refresh", forControlEvents: .ValueChanged)
            self.refreshControl?.beginRefreshing()
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "articleRead:",
                name: "ArticleWasRead", object: nil)
        }
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func articleRead(note: NSNotification) {
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }

    public override func viewDidAppear(animated: Bool) {
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
            mainQueue.addOperationWithBlock {
                let articles = feeds.reduce(Array<Article>()) { return $0 + $1.articles }
                let newArticles = Set<Article>(articles)
                let oldArticles = Set<Article>(self.articles)
                if newArticles != oldArticles {
                    self.articles = (articles as [Article])
                    self.articles.sort({(a: Article, b: Article) in
                        let da = a.updatedAt ?? a.published
                        let db = b.updatedAt ?? b.published
                        return da.timeIntervalSince1970 > db.timeIntervalSince1970
                    })
                }
                if newArticles != oldArticles {
                    self.tableView.reloadData()
                }
                self.refreshControl?.endRefreshing()
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
        let avc = splitViewController?.viewControllers.last as? ArticleViewController ??
            ArticleViewController()
        avc.dataManager = dataManager
        avc.article = article
        avc.articles = self.articles
        if (self.articles.count != 0) {
//            avc.lastArticleIndex = (self.articles as NSArray).indexOfObject(article)
        } else {
            avc.lastArticleIndex = 0
        }
        if let splitView = self.splitViewController {
            let delegate = UIApplication.sharedApplication().delegate as? AppDelegate
            delegate?.splitDelegate.collapseDetailViewController = false
            splitView.showDetailViewController(UINavigationController(rootViewController: avc),
                sender: self)
        } else {
            self.navigationController?.pushViewController(avc, animated: animated)
        }
        return avc
    }

    // MARK: - Table view data source

    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
    }

    public override func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath _: NSIndexPath) -> CGFloat {
//        let article = articleForIndexPath(indexPath)

//        if article.content == nil {
//            return 40
//        }
        return 40
    }

    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let article = articleForIndexPath(indexPath)
        let strToUse = (article.read ? "read" : "unread")
        // Prevents a green triangle which'll (dis)appear depending
        // on whether article loaded into it is read or not.
        let cell = tableView.dequeueReusableCellWithIdentifier(strToUse, forIndexPath: indexPath) as! ArticleCell

        cell.article = article

        return cell
    }

    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        if !previewMode {
            showArticle(articleForIndexPath(indexPath))
        }
    }

    public override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    public override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle,
        forRowAtIndexPath indexPath: NSIndexPath) {
    }

    public override func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
            if previewMode {
                return nil
            }
            let article = self.articleForIndexPath(indexPath)
            let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Delete", comment: ""),
                handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
                    //            article.managedObjectContext?.deleteObject(article)
                    //            article.managedObjectContext?.save(nil)
                    self.refresh()
            })
            let unread = NSLocalizedString("Mark\nUnread", comment: "")
            let read = NSLocalizedString("Mark\nRead", comment: "")
            let toggleText = article.read ? unread : read
            let toggle = UITableViewRowAction(style: .Normal, title: toggleText,
                handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
                    //            self.dataManager?.readArticle(article)
                    tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
            })
            return [delete, toggle]
    }
}

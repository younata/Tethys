import UIKit
import rNewsKit

public class ArticleListController: UITableViewController, DataSubscriber {

    internal var articles: [Article] = []
    public var feeds: [Feed] = [] {
        didSet {
            let articles: [Article] = self.feeds.reduce(Array<Article>()) { return $0 + $1.articles }
            self.articles = articles.sort {a, b in
                let da = a.updatedAt ?? a.published
                let db = b.updatedAt ?? b.published
                return da.timeIntervalSince1970 > db.timeIntervalSince1970
            }
            self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
        }
    }

    public var previewMode: Bool = false

    lazy var dataWriter: DataWriter? = {
        self.injector?.create(DataWriter.self) as? DataWriter
    }()
    lazy var mainQueue: NSOperationQueue? = {
        self.injector?.create(kMainQueue) as? NSOperationQueue
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.estimatedRowHeight = 40
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "read")
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on whether
        // article loaded into it is read or not.

        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.tableFooterView = UIView()

        self.dataWriter?.addSubscriber(self)

        if !previewMode {
            self.navigationItem.rightBarButtonItem = self.editButtonItem()

            if feeds.count == 1 {
                self.navigationItem.title = feeds.first?.displayTitle
            }
        }
    }

    public func deletedArticle(article: Article) {}

    public func willUpdateFeeds() {}
    public func didUpdateFeedsProgress(finished: Int, total: Int) {}
    public func didUpdateFeeds(feeds: [Feed]) {}

    public func markedArticle(article: Article, asRead read: Bool) {
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }

    private func articleForIndexPath(indexPath: NSIndexPath) -> Article {
        return articles[indexPath.row]
    }

    public func showArticle(article: Article, animated: Bool = true) -> ArticleViewController {
        let avc = splitViewController?.viewControllers.last as? ArticleViewController ??
            ArticleViewController()
        avc.dataWriter = dataWriter
        avc.article = article
        avc.articles = self.articles
        if (self.articles.count != 0) {
            avc.lastArticleIndex = self.articles.indexOf(article) ?? 0
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

    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return articles.count
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
        return !previewMode
    }

    public override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle,
        forRowAtIndexPath indexPath: NSIndexPath) {}

    public override func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            if previewMode {
                return nil
            }
            let article = self.articleForIndexPath(indexPath)
            let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Delete", comment: ""),
                handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
                    self.dataWriter?.deleteArticle(article)
            })
            let unread = NSLocalizedString("Mark\nUnread", comment: "")
            let read = NSLocalizedString("Mark\nRead", comment: "")
            let toggleText = article.read ? unread : read
            let toggle = UITableViewRowAction(style: .Normal, title: toggleText,
                handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
                    article.read = !article.read
                    self.dataWriter?.markArticle(article, asRead: article.read)
                    tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
            })
            return [delete, toggle]
    }
}

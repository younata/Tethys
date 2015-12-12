import UIKit
import rNewsKit

public class ArticleListController: UITableViewController, DataSubscriber {

    internal var articles = CoreDataBackedArray<Article>()
    public var feeds: [Feed] = [] {
        didSet {
            self.resetArticles()
        }
    }

    public var previewMode: Bool = false

    internal lazy var dataWriter: DataWriter? = {
        self.injector?.create(DataWriter.self) as? DataWriter
    }()

    internal lazy var dataReader: DataRetriever? = {
        self.injector?.create(DataRetriever.self) as? DataRetriever
    }()

    internal lazy var themeRepository: ThemeRepository? = {
        self.injector?.create(ThemeRepository.self) as? ThemeRepository
    }()

    public lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: CGRectMake(0, 0, 320, 32))
        searchBar.autocorrectionType = .No
        searchBar.autocapitalizationType = .None
        searchBar.placeholder = NSLocalizedString("ArticleListController_Search", comment: "")
        searchBar.delegate = self
        return searchBar
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.estimatedRowHeight = 40
        self.tableView.keyboardDismissMode = .OnDrag
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "read")
        self.tableView.registerClass(ArticleCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on whether
        // article loaded into it is read or not.

        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.tableFooterView = UIView()

        self.dataWriter?.addSubscriber(self)

        self.themeRepository?.addSubscriber(self)

        if !self.previewMode {
            self.tableView.tableHeaderView = self.searchBar
            self.navigationItem.rightBarButtonItem = self.editButtonItem()

            if self.feeds.count == 1 {
                self.navigationItem.title = self.feeds.first?.displayTitle
            }

            if #available(iOS 9.0, *) {
                if self.traitCollection.forceTouchCapability == .Available {
                    self.registerForPreviewingWithDelegate(self, sourceView: self.tableView)
                }
            }
        }
    }

    public func deletedArticle(article: Article) {}
    public func willUpdateFeeds() {}
    public func didUpdateFeedsProgress(finished: Int, total: Int) {}
    public func didUpdateFeeds(feeds: [Feed]) {}
    public func deletedFeed(feed: Feed, feedsLeft: Int) {}

    public func markedArticles(articles: [Article], asRead read: Bool) {
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .None)
    }

    private func articleForIndexPath(indexPath: NSIndexPath) -> Article {
        return self.articles[indexPath.row]
    }

    public func showArticle(article: Article, animated: Bool = true) -> ArticleViewController {
        let avc = self.configuredArticleController(article)
        self.showArticleController(avc, animated: animated)
        return avc
    }

    private func configuredArticleController(article: Article, read: Bool = true) -> ArticleViewController {
        let avc = splitViewController?.viewControllers.last as? ArticleViewController ??
            ArticleViewController()
        avc.dataWriter = self.dataWriter
        avc.themeRepository = self.themeRepository
        avc.setArticle(article, read: read)
        avc.articles = self.articles
        if self.articles.count != 0 {
            avc.lastArticleIndex = self.articles.indexOf(article) ?? 0
        } else {
            avc.lastArticleIndex = 0
        }
        return avc
    }

    private func showArticleController(avc: ArticleViewController, animated: Bool) {
        if let splitView = self.splitViewController {
            let delegate = UIApplication.sharedApplication().delegate as? AppDelegate
            delegate?.splitView.collapseDetailViewController = false
            splitView.showDetailViewController(UINavigationController(rootViewController: avc),
                sender: self)
        } else {
            if avc != self.navigationController?.topViewController {
                self.navigationController?.pushViewController(avc, animated: animated)
            }
        }
    }

    // MARK: - Table view data source

    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.articles.count
    }

    public override func tableView(tableView: UITableView,
        cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            let article = self.articleForIndexPath(indexPath)
            let cellTypeToUse = (article.read ? "read" : "unread")
            // Prevents a green triangle which'll (dis)appear depending
            // on whether article loaded into it is read or not.
            let cell = tableView.dequeueReusableCellWithIdentifier(cellTypeToUse,
                forIndexPath: indexPath) as! ArticleCell

            cell.themeRepository = self.themeRepository
            cell.article = article

        return cell
    }

    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        if !self.previewMode {
            self.showArticle(self.articleForIndexPath(indexPath))
        }
    }

    public override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return !self.previewMode
    }

    public override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle,
        forRowAtIndexPath indexPath: NSIndexPath) {}

    public override func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            if self.previewMode {
                return nil
            }
            let article = self.articleForIndexPath(indexPath)
            let delete = UITableViewRowAction(style: .Default, title: NSLocalizedString("Generic_Delete", comment: ""),
                handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
                    self.dataWriter?.deleteArticle(article)
                    self.articles.remove(article)
                    self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            })
            let unread = NSLocalizedString("ArticleListController_Cell_EditAction_MarkUnread", comment: "")
            let read = NSLocalizedString("ArticleListController_Cell_EditAction_MarkRead", comment: "")
            let toggleText = article.read ? unread : read
            let toggle = UITableViewRowAction(style: .Normal, title: toggleText,
                handler: {(action: UITableViewRowAction!, indexPath: NSIndexPath!) in
                    article.read = !article.read
                    self.dataWriter?.markArticle(article, asRead: article.read)
                    tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            })
            return [delete, toggle]
    }

    // Mark: Private

    private func resetArticles() {
        guard var articles = self.feeds.first?.articlesArray else { return }
        for feed in self.feeds[1..<self.feeds.count] {
            articles = articles.combine(feed.articlesArray)
        }
        self.articles = articles
        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }
}

extension ArticleListController: UISearchBarDelegate {
    public func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            self.resetArticles()
        } else {
            self.dataReader?.articlesOfFeeds(self.feeds, matchingSearchQuery: searchText) {articles in
                let articlesArray = articles
                if self.articles != articlesArray {
                    self.articles = articlesArray
                    self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
                }
            }
        }
    }
}

extension ArticleListController: UIViewControllerPreviewingDelegate {
    public func previewingContext(previewingContext: UIViewControllerPreviewing,
        viewControllerForLocation location: CGPoint) -> UIViewController? {
            if let indexPath = self.tableView.indexPathForRowAtPoint(location) where !self.previewMode {
                let article = self.articleForIndexPath(indexPath)
                return self.configuredArticleController(article, read: false)
            }
            return nil
    }

    public func previewingContext(previewingContext: UIViewControllerPreviewing,
        commitViewController viewControllerToCommit: UIViewController) {
            if let articleController = viewControllerToCommit as? ArticleViewController,
                article = articleController.article where !self.previewMode {
                    self.dataWriter?.markArticle(article, asRead: true)
                    self.showArticleController(articleController, animated: true)
            }
    }
}

extension ArticleListController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.tableView.backgroundColor = self.themeRepository?.backgroundColor
        self.tableView.separatorColor = self.themeRepository?.textColor

        self.searchBar.backgroundColor = self.themeRepository?.backgroundColor

        if let themeRepository = self.themeRepository {
            self.searchBar.barStyle = themeRepository.barStyle

            self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle

            self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        }
    }
}

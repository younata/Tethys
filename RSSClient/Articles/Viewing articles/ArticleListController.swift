import UIKit
import rNewsKit
import Ra

public final class ArticleListController: UITableViewController, DataSubscriber, Injectable {
    internal var articles = DataStoreBackedArray<Article>()
    public var feed: Feed? {
        didSet {
            self.resetArticles()
            self.resetBarItems()
        }
    }

    public var previewMode: Bool = false

    fileprivate let feedRepository: DatabaseUseCase
    fileprivate let themeRepository: ThemeRepository
    fileprivate let settingsRepository: SettingsRepository
    fileprivate let articleViewController: (Void) -> ArticleViewController

    public lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: 320, height: 32))
        searchBar.autocorrectionType = .no
        searchBar.autocapitalizationType = .none
        searchBar.placeholder = NSLocalizedString("ArticleListController_Search", comment: "")
        searchBar.delegate = self
        return searchBar
    }()

    public init(feedRepository: DatabaseUseCase,
                themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                articleViewController: @escaping (Void) -> ArticleViewController) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.articleViewController = articleViewController

        super.init(style: .plain)
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(kind: DatabaseUseCase.self)!,
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            settingsRepository: injector.create(kind: SettingsRepository.self)!,
            articleViewController: { injector.create(kind: ArticleViewController.self)! }
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.estimatedRowHeight = 40
        self.tableView.keyboardDismissMode = .onDrag
        self.tableView.register(ArticleCell.self, forCellReuseIdentifier: "read")
        self.tableView.register(ArticleCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on whether
        // article loaded into it is read or not.

        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.tableFooterView = UIView()

        self.feedRepository.addSubscriber(self)

        self.themeRepository.addSubscriber(self)

        if !self.previewMode {
            self.tableView.tableHeaderView = self.searchBar

            if let feed = self.feed {
                self.navigationItem.title = feed.displayTitle
            }

            self.registerForPreviewing(with: self, sourceView: self.tableView)
            self.resetBarItems()
        }
    }

    public func deletedArticle(_ article: Article) {}
    public func willUpdateFeeds() {}
    public func didUpdateFeedsProgress(_ finished: Int, total: Int) {}
    public func didUpdateFeeds(_ feeds: [Feed]) {}
    public func deletedFeed(_ feed: Feed, feedsLeft: Int) {}

    public func markedArticles(_ articles: [Article], asRead read: Bool) {
        let indices = articles.flatMap { self.articles.index(of: $0) }

        let indexPaths = indices.map { IndexPath(row: $0, section: 0) }
        self.tableView.reloadRows(at: indexPaths, with: .right)
    }

    fileprivate func articleForIndexPath(_ indexPath: IndexPath) -> Article {
        return self.articles[indexPath.row]
    }

    public func showArticle(_ article: Article, animated: Bool = true) -> ArticleViewController {
        let avc = self.configuredArticleController(article)
        self.showArticleController(avc, animated: animated)
        return avc
    }

    fileprivate func configuredArticleController(_ article: Article, read: Bool = true) -> ArticleViewController {
        let articleViewController = self.articleViewController()
        articleViewController.setArticle(article, read: read)
        return articleViewController
    }

    fileprivate func showArticleController(_ avc: ArticleViewController, animated: Bool) {
        if let splitView = self.splitViewController {
            let delegate = UIApplication.shared.delegate as? AppDelegate
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

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.articles.count
    }

    public override func tableView(_ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let article = self.articleForIndexPath(indexPath)
            let cellTypeToUse = (article.read ? "read" : "unread")
            // Prevents a green triangle which'll (dis)appear depending
            // on whether article loaded into it is read or not.
        let cell = tableView.dequeueReusableCell(withIdentifier: cellTypeToUse,
                                                 for: indexPath) as! ArticleCell

            cell.themeRepository = self.themeRepository
            cell.settingsRepository = self.settingsRepository
            cell.article = article

        return cell
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if !self.previewMode {
            _ = self.showArticle(self.articleForIndexPath(indexPath))
        }
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !self.previewMode
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle,
        forRowAt indexPath: IndexPath) {}

    public override func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
            if self.previewMode {
                return nil
            }
            let article = self.articleForIndexPath(indexPath)
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let delete = UITableViewRowAction(style: .default, title: deleteTitle,
                handler: {(action: UITableViewRowAction!, indexPath: IndexPath!) in

                    let confirmDelete = NSLocalizedString("Generic_ConfirmDelete", comment: "")
                    let deleteAlertTitle = NSString.localizedStringWithFormat(confirmDelete as NSString,
                                                                              article.title) as String
                    let alert = UIAlertController(title: deleteAlertTitle, message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: deleteTitle, style: .destructive) { _ in
                        _ = self.articles.remove(article)
                        _ = self.feedRepository.deleteArticle(article)
                        tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.dismiss(animated: true, completion: nil)
                    })
                    let cancelTitle = NSLocalizedString("Generic_Cancel", comment: "")
                    alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
                        tableView.reloadRows(at: [indexPath], with: .right)
                        self.dismiss(animated: true, completion: nil)
                    })
                    self.present(alert, animated: true, completion: nil)
            })
            let unread = NSLocalizedString("ArticleListController_Cell_EditAction_MarkUnread", comment: "")
            let read = NSLocalizedString("ArticleListController_Cell_EditAction_MarkRead", comment: "")
            let toggleText = article.read ? unread : read
            let toggle = UITableViewRowAction(style: .normal, title: toggleText,
                handler: {(action: UITableViewRowAction!, indexPath: IndexPath!) in
                    article.read = !article.read
                    _ = self.feedRepository.markArticle(article, asRead: article.read)
            })
            return [delete, toggle]
    }

    // Mark: Private

    fileprivate func resetArticles() {
        guard let articles = self.feed?.articlesArray else { return }
        self.articles = articles
        self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
    }

    fileprivate func resetBarItems() {
        guard !self.previewMode else { return }

        var barItems = [self.editButtonItem]

        if let _ = self.feed {
            let shareSheet = UIBarButtonItem(barButtonSystemItem: .action,
                                             target: self,
                                             action: #selector(ArticleListController.shareFeed))
            barItems.append(shareSheet)
        }

        self.navigationItem.rightBarButtonItems = barItems
    }

    @objc fileprivate func shareFeed() {
        guard let url = self.feed?.url else { return }
        let shareSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        self.present(shareSheet, animated: true, completion: nil)
    }
}

extension ArticleListController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            self.resetArticles()
        } else if let feed = self.feed {
            let articlesArray = self.feedRepository.articles(feed: feed, matchingSearchQuery: searchText)
            if self.articles != articlesArray {
                self.articles = articlesArray
                self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
            }
        }
    }
}

extension ArticleListController: UIViewControllerPreviewingDelegate {
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
        viewControllerForLocation location: CGPoint) -> UIViewController? {
            if let indexPath = self.tableView.indexPathForRow(at: location), !self.previewMode {
                let article = self.articleForIndexPath(indexPath)
                return self.configuredArticleController(article, read: false)
            }
            return nil
    }

    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
        commit viewControllerToCommit: UIViewController) {
            if let articleController = viewControllerToCommit as? ArticleViewController,
                let article = articleController.article, !self.previewMode {
                    _ = self.feedRepository.markArticle(article, asRead: true)
                    self.showArticleController(articleController, animated: true)
            }
    }
}

extension ArticleListController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableView.separatorColor = themeRepository.textColor
        self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.searchBar.backgroundColor = themeRepository.backgroundColor
        self.searchBar.barStyle = themeRepository.barStyle

        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
    }
}

import UIKit
import rNewsKit
import Ra
import CBGPromise

public final class ArticleListController: UITableViewController, DataSubscriber, Injectable {
    fileprivate enum ArticleListSection: Int {
        case overview = 0
        case articles = 1

        static var numberOfSections = 2
    }

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
        self.tableView.register(ArticleListHeaderCell.self, forCellReuseIdentifier: "headerCell")
        // Prevents a green triangle which'll (dis)appear depending on whether
        // article loaded into it is read or not.

        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.tableFooterView = UIView()

        self.feedRepository.addSubscriber(self)

        self.themeRepository.addSubscriber(self)

        if !self.previewMode {
            if let feed = self.feed {
                self.navigationItem.title = feed.displayTitle
            }

            self.registerForPreviewing(with: self, sourceView: self.tableView)
            self.resetBarItems()
        }
    }

    var _previewActionItems: [UIPreviewAction] = []
    public override var previewActionItems: [UIPreviewActionItem] {
        return self._previewActionItems
    }

    public func deletedArticle(_ article: Article) {}
    public func willUpdateFeeds() {}
    public func didUpdateFeedsProgress(_ finished: Int, total: Int) {}
    public func didUpdateFeeds(_ feeds: [Feed]) {}
    public func deletedFeed(_ feed: Feed, feedsLeft: Int) {}

    public func markedArticles(_ articles: [Article], asRead read: Bool) {
        let indices = articles.flatMap { self.articles.index(of: $0) }

        let indexPaths = indices.map { IndexPath(row: $0, section: ArticleListSection.articles.rawValue) }
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

    fileprivate func attemptDelete(article: Article) -> Future<Bool> {
        let confirmDelete = NSLocalizedString("Generic_ConfirmDelete", comment: "")
        let deleteAlertTitle = NSString.localizedStringWithFormat(confirmDelete as NSString,
                                                                  article.title) as String
        let alert = UIAlertController(title: deleteAlertTitle, message: "", preferredStyle: .alert)
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let promise = Promise<Bool>()
        alert.addAction(UIAlertAction(title: deleteTitle, style: .destructive) { _ in
            _ = self.articles.remove(article)
            _ = self.feedRepository.deleteArticle(article)
            promise.resolve(true)
            self.dismiss(animated: true, completion: nil)
        })
        let cancelTitle = NSLocalizedString("Generic_Cancel", comment: "")
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            promise.resolve(false)
            self.dismiss(animated: true, completion: nil)
        })
        self.present(alert, animated: true, completion: nil)
        return promise.future
    }

    fileprivate func toggleRead(article: Article) {
        article.read = !article.read
        _ = self.feedRepository.markArticle(article, asRead: article.read)
    }

    // MARK: - Table view data source

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return ArticleListSection.numberOfSections
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = ArticleListSection(rawValue: section) else { return 0 }
        switch section {
        case .overview:
            if let _ = self.feed {
                return 1
            }
            return 0
        case .articles:
            return self.articles.count
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = ArticleListSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        switch section {
        case .overview:
            if let feed = self.feed {
                let cell = tableView.dequeueReusableCell(withIdentifier: "headerCell",
                                                         for: indexPath) as! ArticleListHeaderCell
                cell.configure(summary: feed.displaySummary, image: feed.image)
                cell.themeRepository = self.themeRepository
                return cell
            }
            return UITableViewCell()
        case .articles:
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
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if !self.previewMode && ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles {
            _ = self.showArticle(self.articleForIndexPath(indexPath))
        }
    }

    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !self.previewMode && ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles
    }

    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle,
        forRowAt indexPath: IndexPath) {}

    public override func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
            if self.previewMode || ArticleListSection(rawValue: indexPath.section) != ArticleListSection.articles {
                return nil
            }
            let article = self.articleForIndexPath(indexPath)
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let delete = UITableViewRowAction(style: .default, title: deleteTitle,
                handler: {(action: UITableViewRowAction!, indexPath: IndexPath!) in
                    _ = self.attemptDelete(article: article).then {
                        if $0 {
                            tableView.deleteRows(at: [indexPath], with: .automatic)
                        } else {
                            tableView.reloadRows(at: [indexPath], with: .right)
                        }
                    }
            })
            let unread = NSLocalizedString("ArticleListController_Cell_EditAction_MarkUnread", comment: "")
            let read = NSLocalizedString("ArticleListController_Cell_EditAction_MarkRead", comment: "")
            let toggleText = article.read ? unread : read
            let toggle = UITableViewRowAction(style: .normal, title: toggleText,
                handler: {(action: UITableViewRowAction!, indexPath: IndexPath!) in
                    self.toggleRead(article: article)
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

extension ArticleListController: UIViewControllerPreviewingDelegate {
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                                  viewControllerForLocation location: CGPoint) -> UIViewController? {
        if let indexPath = self.tableView.indexPathForRow(at: location), !self.previewMode &&
            ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles {
                let article = self.articleForIndexPath(indexPath)
                let articleController = self.configuredArticleController(article, read: false)
                articleController._previewActionItems = self.previewItems(article: article)
                return articleController
        }
        return nil
    }

    private func previewItems(article: Article) -> [UIPreviewAction] {
        let toggleReadTitle: String
        if article.read {
            toggleReadTitle = NSLocalizedString("ArticleListController_PreviewItem_MarkUnread", comment: "")
        } else {
            toggleReadTitle = NSLocalizedString("ArticleListController_PreviewItem_MarkRead", comment: "")
        }
        let toggleRead = UIPreviewAction(title: toggleReadTitle, style: .default) { _ in
            self.toggleRead(article: article)
        }
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UIPreviewAction(title: deleteTitle, style: .destructive) { _ in
            _ = self.attemptDelete(article: article)
        }
        return [toggleRead, delete]
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

        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
    }
}

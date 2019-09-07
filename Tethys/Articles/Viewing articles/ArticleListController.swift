import UIKit
import TethysKit
import CBGPromise

public final class ArticleListController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    fileprivate enum ArticleListSection: Int {
        case overview = 0
        case articles = 1

        static var numberOfSections = 2
    }

    public private(set) var articles = AnyCollection<Article>([])

    public private(set) lazy var markReadButton: UIBarButtonItem = {
        return UIBarButtonItem(title: NSLocalizedString("ArticleListController_Action_MarkRead", comment: ""),
                               style: .plain, target: self, action: #selector(ArticleListController.markFeedRead))
    }()
    public private(set) lazy var shareButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .action, target: self,
                               action: #selector(ArticleListController.shareFeed))
    }()

    public let tableView = UITableView(forAutoLayout: ())

    public let feed: Feed
    fileprivate let feedService: FeedService
    fileprivate let articleService: ArticleService
    private let themeRepository: ThemeRepository
    private let notificationCenter: NotificationCenter
    private let articleCellController: ArticleCellController
    fileprivate let articleViewController: (Article) -> ArticleViewController

    public init(feed: Feed,
                feedService: FeedService,
                articleService: ArticleService,
                themeRepository: ThemeRepository,
                notificationCenter: NotificationCenter,
                articleCellController: ArticleCellController,
                articleViewController: @escaping (Article) -> ArticleViewController) {
        self.feed = feed
        self.feedService = feedService
        self.articleService = articleService
        self.themeRepository = themeRepository
        self.notificationCenter = notificationCenter
        self.articleCellController = articleCellController
        self.articleViewController = articleViewController

        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.estimatedRowHeight = 40
        self.tableView.keyboardDismissMode = .onDrag
        self.tableView.register(ArticleCell.self, forCellReuseIdentifier: "read")
        self.tableView.register(ArticleCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on whether
        // article loaded into it is read or not.
        self.tableView.register(ArticleListHeaderCell.self, forCellReuseIdentifier: "headerCell")

        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.tableFooterView = UIView()

        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges()

        self.navigationItem.title = self.feed.displayTitle

        self.tableView.allowsMultipleSelection = false

        self.registerForPreviewing(with: self, sourceView: self.tableView)
        self.resetArticles()
        self.resetBarItems()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.themeRepository.addSubscriber(self)
    }

    var _previewActionItems: [UIPreviewAction] = []
    public override var previewActionItems: [UIPreviewActionItem] { return self._previewActionItems }

    fileprivate func articleForIndexPath(_ indexPath: IndexPath) -> Article {
        let index = self.articles.index(self.articles.startIndex, offsetBy: indexPath.row)
        return self.articles[index]
    }

    public func showArticle(_ article: Article, animated: Bool = true) -> ArticleViewController {
        let avc = self.articleViewController(article)
        self.markRead(article: article, read: true)
        self.showArticleController(avc, animated: animated)
        return avc
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
        return self.articleService.remove(article: article).map { result -> Bool in
            switch result {
            case .success:
                self.articles = AnyCollection(self.articles.filter { $0 != article })
                return true
            case .failure(let error):
                self.showAlert(
                    error: error,
                    title: NSLocalizedString("ArticleListController_Action_Delete_Error_Title", comment: "")
                )
                return false
            }
        }
    }

    fileprivate func toggleRead(article: Article) {
        self.markRead(article: article, read: !article.read)
    }

    fileprivate func markRead(article: Article, read: Bool) {
        self.articleService.mark(article: article, asRead: read).then { result in
            switch result {
            case .success(let updatedArticle):
                self.update(article: article, to: updatedArticle)
                self.notificationCenter.post(name: Notifications.reloadUI, object: self)
            case .failure(let error):
                self.showAlert(
                    error: error,
                    title: NSLocalizedString("ArticleListController_Action_Save_Error_Title", comment: "")
                )
            }
        }
    }

    fileprivate func update(article: Article, to updatedArticle: Article) {
        guard let collectionIndex = self.articles.firstIndex(of: article) else { return }
        let index = self.articles.distance(from: self.articles.startIndex, to: collectionIndex)
        self.articles = AnyCollection(self.articles.map({
            if $0 == article {
                return updatedArticle
            }
            return $0
        }))
        self.tableView.reloadRows(at: [IndexPath(row: index, section: 1)], with: .automatic)
    }

    // MARK: - Table view data source

    public func numberOfSections(in tableView: UITableView) -> Int { return ArticleListSection.numberOfSections }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = ArticleListSection(rawValue: section) else { return 0 }
        switch section {
        case .overview:
            if self.feed.image != nil || !self.feed.displaySummary.isEmpty {
                return 1
            }
            return 0
        case .articles:
            return self.articles.count
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = ArticleListSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        switch section {
        case .overview:
            let cell = tableView.dequeueReusableCell(withIdentifier: "headerCell",
                                                     for: indexPath) as! ArticleListHeaderCell
            cell.configure(summary: self.feed.displaySummary, image: self.feed.image)
            cell.themeRepository = self.themeRepository
            return cell
        case .articles:
            let article = self.articleForIndexPath(indexPath)
            let cellTypeToUse = (article.read ? "read" : "unread")
            // Prevents a green triangle which'll (dis)appear depending
            // on whether article loaded into it is read or not.
            let cell = tableView.dequeueReusableCell(withIdentifier: cellTypeToUse,
                                                     for: indexPath) as! ArticleCell

            cell.themeRepository = self.themeRepository

            self.articleCellController.configure(cell: cell, with: article)

            return cell
        }
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles {
            let article = self.articleForIndexPath(indexPath)
            tableView.deselectRow(at: indexPath, animated: false)
            _ = self.showArticle(article)
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles
    }

    public func tableView(_ tableView: UITableView,
                          commit editingStyle: UITableViewCell.EditingStyle,
                          forRowAt indexPath: IndexPath) {}

    public func tableView(_ tableView: UITableView,
                          editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if ArticleListSection(rawValue: indexPath.section) != ArticleListSection.articles {
            return nil
        }
        let article = self.articleForIndexPath(indexPath)
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UITableViewRowAction(style: .default, title: deleteTitle, handler: { _, _  in
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
        let toggle = UITableViewRowAction(style: .normal, title: toggleText, handler: { _, _  in
            self.toggleRead(article: article)
        })

        return [delete, toggle]
    }

    // MARK: Private

    fileprivate func resetArticles() {
        self.feedService.articles(of: self.feed).then { result in
            switch result {
            case .success(let articles):
                self.articles = articles
                self.tableView.beginUpdates()
                self.tableView.reloadSections(IndexSet(integer: 0), with: .none)
                self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
                self.tableView.endUpdates()
            case .failure(let error):
                self.showAlert(
                    error: error,
                    title: NSLocalizedString("ArticleListController_Retrieving_Error_Title", comment: "")
                )
            }
        }
    }

    fileprivate func resetBarItems() {
        self.navigationItem.rightBarButtonItems = [self.shareButton, self.markReadButton]
    }

    private func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }

    @objc fileprivate func shareFeed() {
        let shareSheet = URLShareSheet(
            url: self.feed.url,
            themeRepository: self.themeRepository,
            activityItems: [self.feed.url],
            applicationActivities: nil
        )
        shareSheet.popoverPresentationController?.barButtonItem = self.shareButton
        self.present(shareSheet, animated: true, completion: nil)
    }

    @objc private func markFeedRead() {
        let indicator = ActivityIndicator(forAutoLayout: ())
        self.view.addSubview(indicator)
        indicator.autoPinEdgesToSuperviewEdges(with: .zero)

        indicator.configure(message: NSLocalizedString("ArticleListController_Action_MarkRead_Indicator", comment: ""))

        self.feedService.readAll(of: self.feed).then { markReadResult in
            switch markReadResult {
            case .success:
                indicator.removeFromSuperview()
                self.resetArticles()
                self.notificationCenter.post(name: Notifications.reloadUI, object: self)
            case let .failure(error):
                indicator.removeFromSuperview()
                self.showAlert(
                    error: error,
                    title: NSLocalizedString("ArticleListController_Action_MarkRead_Error_Title", comment: "")
                )
            }
        }
    }

    private func showAlert(error: TethysError, title: String) {
        let alert = UIAlertController(title: title,
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Generic_Ok", comment: ""),
                                      style: .default) { _ in
                                        self.dismiss(animated: true, completion: nil)
        })
        self.present(alert, animated: true, completion: nil)
    }
}

extension ArticleListController: UIViewControllerPreviewingDelegate {
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                                  viewControllerForLocation location: CGPoint) -> UIViewController? {
        if let indexPath = self.tableView.indexPathForRow(at: location),
            ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles {
                let article = self.articleForIndexPath(indexPath)
                let articleController = self.articleViewController(article)
                articleController._previewActionItems = self.previewItems(article: article)
                return articleController
        }
        return nil
    }

    private func previewItems(article: Article) -> [UIPreviewAction] {
        let toggleReadTitle: String
        if article.read {
            toggleReadTitle = NSLocalizedString("ArticleListController_Action_MarkUnread", comment: "")
        } else {
            toggleReadTitle = NSLocalizedString("ArticleListController_Action_MarkRead", comment: "")
        }
        let toggleRead = UIPreviewAction(title: toggleReadTitle, style: .default) { _, _  in
            self.toggleRead(article: article)
        }
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UIPreviewAction(title: deleteTitle, style: .destructive) { _, _  in
            _ = self.attemptDelete(article: article)
        }
        return [toggleRead, delete]
    }

    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                                  commit viewControllerToCommit: UIViewController) {
        if let articleController = viewControllerToCommit as? ArticleViewController {
            self.markRead(article: articleController.article, read: true)
            self.showArticleController(articleController, animated: true)
        }
    }
}

extension ArticleListController: SettingsRepositorySubscriber {
    public func didChangeSetting(_: SettingsRepository) { self.tableView.reloadData() }
}

extension ArticleListController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableView.separatorColor = themeRepository.textColor
        self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: themeRepository.textColor
        ]
    }
}

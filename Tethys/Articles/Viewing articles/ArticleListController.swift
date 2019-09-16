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
        let button = UIBarButtonItem(image: UIImage(named: "MarkRead"), style: .plain, target: self,
                                     action: #selector(ArticleListController.markFeedRead))
        button.accessibilityLabel = String.localizedStringWithFormat(
            NSLocalizedString("ArticleListController_Action_Accessibility_MarkFeedAsRead", comment: ""),
            self.feed.displayTitle)
        return button
    }()
    public private(set) lazy var shareButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .action, target: self,
                                     action: #selector(ArticleListController.shareFeed))
        button.accessibilityIdentifier = "ArticleListController_ShareFeed"
        button.accessibilityLabel = String.localizedStringWithFormat(
            NSLocalizedString("ArticleListController_Action_Accessibility_ShareFeed", comment: ""),
            self.feed.displayTitle
        )
        button.isAccessibilityElement = true
        return button
    }()

    public let tableView = UITableView(forAutoLayout: ())

    public let feed: Feed
    fileprivate let feedService: FeedService
    fileprivate let articleService: ArticleService
    private let notificationCenter: NotificationCenter
    private let articleCellController: ArticleCellController
    fileprivate let articleViewController: (Article) -> ArticleViewController

    public init(feed: Feed,
                feedService: FeedService,
                articleService: ArticleService,
                notificationCenter: NotificationCenter,
                articleCellController: ArticleCellController,
                articleViewController: @escaping (Article) -> ArticleViewController) {
        self.feed = feed
        self.feedService = feedService
        self.articleService = articleService
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

        self.resetArticles()
        self.resetBarItems()

        self.tableView.backgroundColor = Theme.backgroundColor
        self.tableView.separatorColor = Theme.separatorColor
    }

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
        if let splitView = self.splitViewController as? SplitViewController {
            splitView.collapseDetailViewController = false
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

    fileprivate func markRead(article: Article, read: Bool, completionHandler: ((Bool) -> Void)? = nil) {
        self.articleService.mark(article: article, asRead: read).then { result in
            switch result {
            case .success(let updatedArticle):
                self.update(article: article, to: updatedArticle)
                self.notificationCenter.post(name: Notifications.reloadUI, object: self)
                completionHandler?(true)
            case .failure(let error):
                self.showAlert(
                    error: error,
                    title: NSLocalizedString("ArticleListController_Action_Save_Error_Title", comment: "")
                )
                completionHandler?(false)
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
            return cell
        case .articles:
            let article = self.articleForIndexPath(indexPath)
            let cellTypeToUse = (article.read ? "read" : "unread")
            // Prevents a green triangle which'll (dis)appear depending
            // on whether article loaded into it is read or not.
            let cell = tableView.dequeueReusableCell(withIdentifier: cellTypeToUse,
                                                     for: indexPath) as! ArticleCell

            self.articleCellController.configure(cell: cell, with: article)

            return cell
        }
    }

    public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles
    }

    public func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles else {
            return nil
        }
        return indexPath
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

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt
                                                    indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard ArticleListSection(rawValue: indexPath.section) == .articles else { return nil }
        let article = self.articleForIndexPath(indexPath)
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UIContextualAction(style: .destructive, title: deleteTitle) { _, _, handler in
            _ = self.attemptDelete(article: article).then { success in
                if success {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                } else {
                    tableView.reloadRows(at: [indexPath], with: .right)
                }
                handler(success)
            }

        }

        let unread = NSLocalizedString("ArticleListController_Cell_EditAction_MarkUnread", comment: "")
        let read = NSLocalizedString("ArticleListController_Cell_EditAction_MarkRead", comment: "")
        let toggleText = article.read ? unread : read
        let toggle = UIContextualAction(style: .normal, title: toggleText) { _, _, handler in
            self.markRead(article: article, read: !article.read, completionHandler: handler)
        }

        let actions = UISwipeActionsConfiguration(actions: [delete, toggle])
        actions.performsFirstActionWithFullSwipe = true

        return actions
    }

    public func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                          point: CGPoint) -> UIContextMenuConfiguration? {
        guard ArticleListSection(rawValue: indexPath.section) == .articles else { return nil }

        let article = self.articleForIndexPath(indexPath)
        return UIContextMenuConfiguration(
            identifier: article.link as NSURL,
            previewProvider: { return self.articleViewController(article) },
            actionProvider: { elements in
                return UIMenu(title: article.title, image: nil, identifier: nil, options: [],
                              children: elements + self.menuActions(for: article))
        })
    }

    public func tableView(_ tableView: UITableView,
                          willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                          animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion { [weak self] in
            guard let articleController = animator.previewViewController as? ArticleViewController else { return }
            self?.markRead(article: articleController.article, read: true)
            self?.showArticleController(articleController, animated: true)
        }
    }

    // MARK: Private

    private func menuActions(for article: Article) -> [UIAction] {
        let toggleReadTitle: String
        if article.read {
            toggleReadTitle = NSLocalizedString("ArticleListController_Action_MarkUnread", comment: "")

        } else {
            toggleReadTitle = NSLocalizedString("ArticleListController_Action_MarkRead", comment: "")
        }
        let toggleRead = UIAction(title: toggleReadTitle, image: UIImage(named: "MarkRead"),
                                  identifier: UIAction.Identifier("MarkRead")) { _ in
                                    self.markRead(article: article, read: !article.read)
        }
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UIAction(title: deleteTitle, image: UIImage(systemName: "trash"),
                              identifier: UIAction.Identifier("Delete"), attributes: [.destructive]) { _ in
                                _ = self.attemptDelete(article: article)
        }
        return [toggleRead, delete]
    }

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

extension ArticleListController: SettingsRepositorySubscriber {
    public func didChangeSetting(_: SettingsRepository) { self.tableView.reloadData() }
}

import UIKit
import TethysKit
import CBGPromise

public final class ArticleListController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private enum ArticleSection: Int {
        case articles = 0
    }

    public private(set) var articles = AnyCollection<Article>([])

    public private(set) lazy var markReadButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(named: "MarkRead"), style: .plain, target: self,
                                     action: #selector(ArticleListController.markFeedRead))
        button.accessibilityLabel = String.localizedStringWithFormat(
            NSLocalizedString("ArticleListController_Action_Accessibility_MarkFeedAsRead", comment: ""),
            self.feed.displayTitle)
        button.isAccessibilityElement = true
        button.accessibilityTraits = [.button]
        return button
    }()
    public private(set) lazy var shareButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .action, target: self,
                                     action: #selector(ArticleListController.shareFeed))
        button.accessibilityIdentifier = "ArticleListController_ShareFeed"
        button.accessibilityLabel = NSLocalizedString("ArticleListController_Action_Accessibility_ShareFeed",
                                                      comment: "")
        button.isAccessibilityElement = true
        button.accessibilityTraits = [.button]
        return button
    }()

    private let tableHeaderView = ArticleListHeaderView(frame: CGRect(x: 0, y: 0, width: 320, height: 10))

    public let tableView = UITableView(forAutoLayout: ())

    public let feed: Feed
    private let mainQueue: OperationQueue
    private let messenger: Messenger
    private let feedCoordinator: FeedCoordinator
    private let articleCoordinator: ArticleCoordinator
    private let notificationCenter: NotificationCenter
    private let articleCellController: ArticleCellController
    private let articleViewController: (Article) -> ArticleViewController

    public init(feed: Feed,
                mainQueue: OperationQueue,
                messenger: Messenger,
                feedCoordinator: FeedCoordinator,
                articleCoordinator: ArticleCoordinator,
                notificationCenter: NotificationCenter,
                articleCellController: ArticleCellController,
                articleViewController: @escaping (Article) -> ArticleViewController) {
        self.feed = feed
        self.mainQueue = mainQueue
        self.messenger = messenger
        self.feedCoordinator = feedCoordinator
        self.articleCoordinator = articleCoordinator
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

        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.tableFooterView = UIView()

        if self.feed.image != nil || !self.feed.displaySummary.isEmpty {
            self.tableHeaderView.configure(summary: self.feed.displaySummary, image: self.feed.image)
            self.tableView.tableHeaderView = self.tableHeaderView
        } else {
            self.tableView.tableHeaderView = nil
        }

        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges()

        self.navigationItem.title = self.feed.displayTitle

        self.tableView.allowsMultipleSelection = false

        self.resetArticles()
        self.resetBarItems()

        self.tableView.backgroundColor = Theme.backgroundColor
        self.tableView.separatorColor = Theme.separatorColor
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.tableHeaderView.frame.size.height = self.tableHeaderView.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize
        ).height
    }

    private func articleForIndexPath(_ indexPath: IndexPath) -> Article {
        let index = self.articles.index(self.articles.startIndex, offsetBy: indexPath.row)
        return self.articles[index]
    }

    public func showArticle(_ article: Article, animated: Bool = true) -> ArticleViewController {
        let avc = self.articleViewController(article)
        self.markRead(article: article, read: true)
        self.showArticleController(avc, animated: animated)
        return avc
    }

    private func showArticleController(_ avc: ArticleViewController, animated: Bool) {
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

    private func attemptDelete(article: Article) -> Future<Bool> {
        return self.articleCoordinator.remove(article: article).map { result -> Bool in
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

    private func markRead(article: Article, read: Bool, completionHandler: ((Bool) -> Void)? = nil) {
        var succeeded = true
        self.articleCoordinator.mark(article: article, asRead: read).then { [weak self] result in
            self?.mainQueue.addOperation {
                switch result {
                case .finished:
                    completionHandler?(succeeded)
                case .update(.success(let updatedArticle)):
                    self?.update(article: article, to: updatedArticle)
                    self?.notificationCenter.post(name: Notifications.reloadUI, object: self)
                case .update(.failure(let error)):
                    self?.showAlert(
                        error: error,
                        title: NSLocalizedString("ArticleListController_Action_Save_Error_Title", comment: "")
                    )
                    succeeded = false
                }
            }
        }
    }

    private func update(article: Article, to updatedArticle: Article) {
        guard let collectionIndex = self.articles.firstIndex(of: article) else { return }
        let index = self.articles.distance(from: self.articles.startIndex, to: collectionIndex)
        self.articles = AnyCollection(self.articles.map({
            if $0 == article {
                return updatedArticle
            }
            return $0
        }))
        let indexPath = IndexPath(row: index, section: ArticleSection.articles.rawValue)
        self.tableView.reloadRows(at: [indexPath], with: .automatic)
    }

    // MARK: - Table view data source

    public func numberOfSections(in tableView: UITableView) -> Int { return 1 }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.articles.underestimatedCount
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let article = self.articleForIndexPath(indexPath)
        let cellTypeToUse = (article.read ? "read" : "unread")
        // Prevents a green triangle which'll (dis)appear depending
        // on whether article loaded into it is read or not.
        let cell = tableView.dequeueReusableCell(withIdentifier: cellTypeToUse,
                                                 for: indexPath) as! ArticleCell

        self.articleCellController.configure(cell: cell, with: article)

        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let article = self.articleForIndexPath(indexPath)
        tableView.deselectRow(at: indexPath, animated: false)
        _ = self.showArticle(article)
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { return true }

    public func tableView(_ tableView: UITableView,
                          commit editingStyle: UITableViewCell.EditingStyle,
                          forRowAt indexPath: IndexPath) {}

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt
                                                    indexPath: IndexPath) -> UISwipeActionsConfiguration? {
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

    private func resetArticles() {
        self.feedCoordinator.articles(of: self.feed).then { [weak self] result in
            self?.mainQueue.addOperation {
                switch result {
                case .update(.success(let articles)):
                    self?.articles = articles
                    self?.tableView.beginUpdates()
                    self?.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                    self?.tableView.endUpdates()
                case .update(.failure(let error)):
                    self?.tableView.beginUpdates()
                    self?.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                    self?.tableView.endUpdates()
                    self?.showAlert(
                        error: error,
                        title: NSLocalizedString("ArticleListController_Retrieving_Error_Title", comment: "")
                    )
                case .finished:
                    break
                }
            }
        }
    }

    private func resetBarItems() {
        self.navigationItem.rightBarButtonItems = [self.shareButton, self.markReadButton]
    }

    private func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }

    @objc private func shareFeed() {
        let shareSheet = UIActivityViewController(
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

        self.feedCoordinator.readAll(of: self.feed).then { [weak self] markReadResult in
            self?.mainQueue.addOperation {
                switch markReadResult {
                case .success:
                    indicator.removeFromSuperview()
                    self?.resetArticles()
                    self?.notificationCenter.post(name: Notifications.reloadUI, object: self)
                case let .failure(error):
                    indicator.removeFromSuperview()
                    self?.showAlert(
                        error: error,
                        title: NSLocalizedString("ArticleListController_Action_MarkRead_Error_Title", comment: "")
                    )
                }
            }
        }
    }

    private func showAlert(error: TethysError, title: String) {
        self.messenger.error(title: title, message: error.localizedDescription)
    }
}

extension ArticleListController: SettingsRepositorySubscriber {
    public func didChangeSetting(_: SettingsRepository) { self.tableView.reloadData() }
}

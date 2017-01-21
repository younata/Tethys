import UIKit
import TethysKit
import Ra
import CBGPromise

public protocol ArticleListControllerDelegate: class {
    func articleListControllerCanSelectMultipleArticles(_: ArticleListController) -> Bool
    func articleListControllerShouldShowToolbar(_: ArticleListController) -> Bool
    func articleListControllerRightBarButtonItems(_: ArticleListController) -> [UIBarButtonItem]
    func articleListController(_: ArticleListController, canEditArticle article: Article) -> Bool
    func articleListController(_: ArticleListController, shouldShowArticleView article: Article) -> Bool
    func articleListController(_: ArticleListController, didSelectArticles articles: [Article])
    func articleListController(_: ArticleListController, shouldPreviewArticle article: Article) -> Bool
}

public final class ArticleListController: UIViewController, DataSubscriber, Injectable,
                                          UITableViewDelegate, UITableViewDataSource {
    fileprivate enum ArticleListSection: Int {
        case overview = 0
        case articles = 1

        static var numberOfSections = 2
    }

    public internal(set) var articles = DataStoreBackedArray<Article>()
    public var feed: Feed? {
        didSet {
            self.resetArticles()
            self.resetBarItems()
        }
    }

    public private(set) lazy var generateBookButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(named: "Book"), style: .plain,
                               target: self, action: #selector(ArticleListController.displayGenerateBookController))
    }()

    public private(set) lazy var markReadButton: UIBarButtonItem = {
        return UIBarButtonItem(title: NSLocalizedString("ArticleListController_Action_MarkRead", comment: ""),
                               style: .plain, target: self, action: #selector(ArticleListController.markFeedRead))
    }()

    public let tableView = UITableView(forAutoLayout: ())

    public weak var delegate: ArticleListControllerDelegate?

    fileprivate let mainQueue: OperationQueue
    fileprivate let feedRepository: DatabaseUseCase
    fileprivate let themeRepository: ThemeRepository
    fileprivate let settingsRepository: SettingsRepository
    fileprivate let articleViewController: (Void) -> ArticleViewController
    fileprivate let generateBookViewController: (Void) -> GenerateBookViewController

    public init(mainQueue: OperationQueue,
                feedRepository: DatabaseUseCase,
                themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                articleViewController: @escaping (Void) -> ArticleViewController,
                generateBookViewController: @escaping (Void) -> GenerateBookViewController) {
        self.mainQueue = mainQueue
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.articleViewController = articleViewController
        self.generateBookViewController = generateBookViewController

        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            mainQueue: injector.create(string: kMainQueue) as! OperationQueue,
            feedRepository: injector.create(kind: DatabaseUseCase.self)!,
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            settingsRepository: injector.create(kind: SettingsRepository.self)!,
            articleViewController: { injector.create(kind: ArticleViewController.self)! },
            generateBookViewController: { injector.create(kind: GenerateBookViewController.self)! }
        )
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
        self.tableView.register(ArticleListHeaderCell.self, forCellReuseIdentifier: "headerCell")
        // Prevents a green triangle which'll (dis)appear depending on whether
        // article loaded into it is read or not.

        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.tableFooterView = UIView()

        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges()

        self.feedRepository.addSubscriber(self)

        if let feed = self.feed {
            self.navigationItem.title = feed.displayTitle
        }

        self.tableView.allowsMultipleSelection = self.delegate?.articleListControllerCanSelectMultipleArticles(self)
            ?? false

        self.registerForPreviewing(with: self, sourceView: self.tableView)
        self.resetBarItems()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !(self.delegate?.articleListControllerShouldShowToolbar(self) == false) {
            self.navigationController?.setToolbarHidden(false, animated: true)
        }
        self.themeRepository.addSubscriber(self)
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

    public func selectArticles() {
        let articles = self.tableView.indexPathsForSelectedRows?.map { self.articleForIndexPath($0) }
        self.delegate?.articleListController(self, didSelectArticles: articles ?? [])
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

    public func numberOfSections(in tableView: UITableView) -> Int {
        return ArticleListSection.numberOfSections
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = ArticleListSection(rawValue: section) else { return 0 }
        switch section {
        case .overview:
            if let feed = self.feed, feed.image != nil || !feed.displaySummary.isEmpty {
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

            let readingTime = self.settingsRepository.showEstimatedReadingLabel ? article.estimatedReadingTime : nil
            cell.configure(
                title: article.title,
                publishedDate: article.updatedAt ?? article.published,
                author: article.authorsString,
                read: article.read,
                readingTime: readingTime
            )

            return cell
        }
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles {
            let article = self.articleForIndexPath(indexPath)
            if self.delegate?.articleListController(self, shouldShowArticleView: article) != false {
                tableView.deselectRow(at: indexPath, animated: false)
                _ = self.showArticle(article)
            } else {
                return
            }
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles {
            return self.delegate?.articleListController(self,
                                                        canEditArticle: self.articleForIndexPath(indexPath)) != false
        } else {
            return false
        }
    }

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle,
        forRowAt indexPath: IndexPath) {}

    public func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
            if ArticleListSection(rawValue: indexPath.section) != ArticleListSection.articles {
                return nil
            }
            let article = self.articleForIndexPath(indexPath)
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let delete = UITableViewRowAction(style: .default, title: deleteTitle,
                handler: {(action: UITableViewRowAction!, _) in
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
                handler: {(action: UITableViewRowAction!, _) in
                    self.toggleRead(article: article)
            })
            return [delete, toggle]
    }

    // Mark: Private

    fileprivate func resetArticles() {
        guard let articles = self.feed?.articlesArray else { return }
        self.articles = articles
        self.tableView.reloadSections(IndexSet(integersIn: 0...1), with: .automatic)
    }

    fileprivate func resetBarItems() {
        if let barItems = self.delegate?.articleListControllerRightBarButtonItems(self) {
            self.navigationItem.rightBarButtonItems = barItems
        } else {
            var barItems = [self.editButtonItem]

            if let _ = self.feed {
                let shareSheet = UIBarButtonItem(barButtonSystemItem: .action,
                                                 target: self,
                                                 action: #selector(ArticleListController.shareFeed))
                barItems.append(shareSheet)
            }

            self.navigationItem.rightBarButtonItems = barItems
        }
        self.setupToolbar()
    }

    private func spacer() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }

    private func setupToolbar() {
        if let _ = self.feed {
            self.toolbarItems = [
                self.spacer(),
                self.generateBookButton,
                self.spacer(),
                self.markReadButton,
                self.spacer()
            ]
        } else {
            self.toolbarItems = [
                self.spacer(),
                self.generateBookButton,
                self.spacer()
            ]
        }
    }

    @objc fileprivate func shareFeed() {
        guard let url = self.feed?.url else { return }
        let shareSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        self.present(shareSheet, animated: true, completion: nil)
    }

    @objc private func displayGenerateBookController() {
        let generateBookController = self.generateBookViewController()
        generateBookController.articles = self.articles
        self.present(
            UINavigationController(rootViewController: generateBookController),
            animated: true,
            completion: nil
        )
    }

    @objc private func markFeedRead() {
        guard let feed = self.feed else { return }

        let indicator = ActivityIndicator(forAutoLayout: ())
        self.view.addSubview(indicator)
        indicator.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)

        indicator.configure(message: NSLocalizedString("ArticleListController_Action_MarkRead_Indicator", comment: ""))

        _ = self.feedRepository.markFeedAsRead(feed).then { markReadResult in
            switch markReadResult {
            case .success(_):
                _ = self.feedRepository.feeds().then { feedsResult in
                    self.mainQueue.addOperation {
                        indicator.removeFromSuperview()

                        switch feedsResult {
                        case let .success(feeds):
                            let feed = feeds.first { $0.url == feed.url }
                            self.feed = feed
                        case let .failure(error):
                            self.showAlert(error: error)
                        }
                    }
                }
                break
            case let .failure(error):
                self.mainQueue.addOperation {
                    indicator.removeFromSuperview()
                    self.showAlert(error: error)
                }
            }
        }
    }

    private func showAlert(error: TethysError) {
        let alertTitle = NSLocalizedString("ArticleListController_Action_MarkRead_Error_Title", comment: "")
        let alert = UIAlertController(title: alertTitle,
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
        // swiftlint:disable line_length
        if let indexPath = self.tableView.indexPathForRow(at: location),
            self.delegate?.articleListController(self, shouldPreviewArticle: self.articleForIndexPath(indexPath)) != false &&
            ArticleListSection(rawValue: indexPath.section) == ArticleListSection.articles {
                let article = self.articleForIndexPath(indexPath)
                let articleController = self.configuredArticleController(article, read: false)
                articleController._previewActionItems = self.previewItems(article: article)
                return articleController
        }
        // swiftlint:enable line_length
        return nil
    }

    private func previewItems(article: Article) -> [UIPreviewAction] {
        let toggleReadTitle: String
        if article.read {
            toggleReadTitle = NSLocalizedString("ArticleListController_Action_MarkUnread", comment: "")
        } else {
            toggleReadTitle = NSLocalizedString("ArticleListController_Action_MarkRead", comment: "")
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
                let article = articleController.article {
                    _ = self.feedRepository.markArticle(article, asRead: true)
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
            NSForegroundColorAttributeName: themeRepository.textColor
        ]
        self.navigationController?.toolbar.barStyle = themeRepository.barStyle
    }
}

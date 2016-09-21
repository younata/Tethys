import UIKit
import BreakOutToRefresh
import Ra
import CBGPromise
import Result
import rNewsKit

// swiftlint:disable file_length

public final class FeedsTableViewController: UIViewController, Injectable {
    public lazy var tableView: UITableView = {
        let tableView = self.tableViewController.tableView!
        tableView.tableHeaderView = self.searchBar
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self

        tableView.register(FeedTableCell.self, forCellReuseIdentifier: "read")
        tableView.register(FeedTableCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.

        return tableView
    }()

    public lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: 320, height: 32))
        searchBar.autocorrectionType = .no
        searchBar.autocapitalizationType = .none
        searchBar.delegate = self
        searchBar.placeholder = NSLocalizedString("FeedsTableViewController_SearchBar_Placeholder", comment: "")
        return searchBar
    }()

    public lazy var updateBar: UIProgressView = {
        let updateBar = UIProgressView(progressViewStyle: .default)
        updateBar.translatesAutoresizingMaskIntoConstraints = false
        updateBar.progressTintColor = UIColor.darkGreen()
        updateBar.trackTintColor = UIColor.clear
        updateBar.isHidden = true
        return updateBar
    }()

    public lazy var refreshView: BreakOutToRefreshView = {
        let refreshView = BreakOutToRefreshView(scrollView: self.tableView)
        refreshView.breakoutDelegate = self
        refreshView.scenebackgroundColor = UIColor.white
        refreshView.paddleColor = UIColor.blue
        refreshView.ballColor = UIColor.darkGreen()
        refreshView.blockColors = [UIColor.darkGray, UIColor.gray, UIColor.lightGray]
        return refreshView
    }()

    public lazy var onboardingView: ExplanationView = {
        let view = ExplanationView(forAutoLayout: ())
        view.title = NSLocalizedString("FeedsTableViewController_Onboarding_Title", comment: "")
        view.detail = NSLocalizedString("FeedsTableViewController_Onboarding_Detail", comment: "")
        view.themeRepository = self.themeRepository
        return view
    }()

    public let loadingView = ActivityIndicator(forAutoLayout: ())

    fileprivate var feeds: [Feed] = []
    private let tableViewController = UITableViewController(style: .plain)
    private var menuTopOffset: NSLayoutConstraint!

    public let notificationView = NotificationView(forAutoLayout: ())

    fileprivate let feedRepository: DatabaseUseCase
    fileprivate let themeRepository: ThemeRepository
    fileprivate let settingsRepository: SettingsRepository

    fileprivate let findFeedViewController: (Void) -> FindFeedViewController
    fileprivate let feedViewController: (Void) -> FeedViewController
    fileprivate let settingsViewController: (Void) -> SettingsViewController
    fileprivate let articleListController: (Void) -> ArticleListController

    fileprivate var markReadFuture: Future<Result<Int, RNewsError>>? = nil

    // swiftlint:disable function_parameter_count
    public init(feedRepository: DatabaseUseCase,
                themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                findFeedViewController: @escaping (Void) -> FindFeedViewController,
                feedViewController: @escaping (Void) -> FeedViewController,
                settingsViewController: @escaping (Void) -> SettingsViewController,
                articleListController: @escaping (Void) -> ArticleListController
        ) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.findFeedViewController = findFeedViewController
        self.feedViewController = feedViewController
        self.settingsViewController = settingsViewController
        self.articleListController = articleListController
        super.init(nibName: nil, bundle: nil)
    }
    // swiftlint:enable function_parameter_count

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(kind: DatabaseUseCase.self)!,
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            settingsRepository: injector.create(kind: SettingsRepository.self)!,
            findFeedViewController: {injector.create(kind: FindFeedViewController.self)!},
            feedViewController: {injector.create(kind: FeedViewController.self)!},
            settingsViewController: {injector.create(kind: SettingsViewController.self)!},
            articleListController: {injector.create(kind: ArticleListController.self)!}
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.addChildViewController(self.tableViewController)
        self.tableView.keyboardDismissMode = .onDrag
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)
        self.tableView.addSubview(self.refreshView)
        self.updateRefreshViewSize(self.view.bounds.size)
        self.tableView.delegate = self

        self.navigationController?.navigationBar.addSubview(self.updateBar)
        if let _ = self.updateBar.superview {
            self.updateBar.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
            self.updateBar.autoSetDimension(.height, toSize: 3)
        }

        self.themeRepository.addSubscriber(self.notificationView)
        self.navigationController?.navigationBar.addSubview(self.notificationView)
        self.notificationView.autoPinEdge(toSuperviewMargin: .trailing)
        self.notificationView.autoPinEdge(toSuperviewMargin: .leading)
        self.notificationView.autoPinEdge(.top, to: .bottom, of: self.navigationController!.navigationBar)

        self.showLoadingView(NSLocalizedString("FeedsTableViewController_Loading_Feeds", comment: ""))

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self,
                                        action: #selector(FeedsTableViewController.didTapAddFeed))
        self.navigationItem.rightBarButtonItems = [addButton, self.tableViewController.editButtonItem]

        let settingsTitle = NSLocalizedString("SettingsViewController_Title", comment: "")
        let settingsButton = UIBarButtonItem(title: settingsTitle,
            style: .plain,
            target: self,
            action: #selector(FeedsTableViewController.presentSettings))
        self.navigationItem.leftBarButtonItem = settingsButton

        self.navigationItem.title = NSLocalizedString("FeedsTableViewController_Title", comment: "")

        NotificationCenter.default.addObserver(self, selector: #selector(UIWebView.reload),
                                                         name: NSNotification.Name(rawValue: "UpdatedFeed"),
                                                         object: nil)

        if self.traitCollection.forceTouchCapability == .available {
            self.registerForPreviewing(with: self, sourceView: self.tableView)
        }

        self.feedRepository.addSubscriber(self)
        self.themeRepository.addSubscriber(self)
        self.reload(self.searchBar.text)
    }

    public override func viewWillAppear(_ animated: Bool) {
        self.updateRefreshViewSize(self.view.bounds.size)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func updateRefreshViewSize(_ size: CGSize) {
        let height: CGFloat = 100
        self.refreshView.frame = CGRect(x: 0, y: -height, width: size.width, height: height)
        self.refreshView.layoutSubviews()
    }

    public override func viewWillTransition(to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)

            self.updateRefreshViewSize(size)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.refreshView.endRefreshing()
    }

    public override var canBecomeFirstResponder: Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        let commands = [
            UIKeyCommand(input: "f", modifierFlags: .command, action: #selector(FeedsTableViewController.search)),
            UIKeyCommand(input: "i", modifierFlags: .command,
                action: #selector(FeedsTableViewController.importFromWeb)),
            UIKeyCommand(input: ",", modifierFlags: .command,
                action: #selector(FeedsTableViewController.presentSettings)),
        ]
        let discoverabilityTitles = [
            NSLocalizedString("FeedsTableViewController_Command_Search", comment: ""),
            NSLocalizedString("FeedsTableViewController_Command_ImportWeb", comment: ""),
            NSLocalizedString("FeedsTableViewController_Command_Settings", comment: ""),
        ]
        for (idx, cmd) in commands.enumerated() {
            cmd.discoverabilityTitle = discoverabilityTitles[idx]
        }
        return commands
    }

    // MARK - Private/Internal

    internal func importFromWeb() { self.presentController(self.findFeedViewController()) }

    @objc fileprivate func search() { self.searchBar.becomeFirstResponder() }

    @objc fileprivate func presentSettings() { self.presentController(self.settingsViewController()) }

    private func presentController(_ viewController: UIViewController) {
        let nc = UINavigationController(rootViewController: viewController)
        if UIDevice.current.userInterfaceIdiom == .pad {
            let popover = UIPopoverController(contentViewController: nc)
            popover.contentSize = CGSize(width: 600, height: 800)
            popover.present(from: self.navigationItem.rightBarButtonItem!,
                permittedArrowDirections: .any, animated: true)
        } else {
            self.present(nc, animated: true, completion: nil)
        }
    }

    private func showLoadingView(_ message: String) {
        self.loadingView.configure(message: message)
        self.view.addSubview(self.loadingView)
        self.loadingView.autoPinEdgesToSuperviewEdges()
    }

    fileprivate func reload(_ tag: String?, feeds: [Feed]? = nil) {
        let reloadWithFeeds: ([Feed]) -> (Void) = {feeds in
            let sortedFeeds = feeds.sorted {(f1: Feed, f2: Feed) in
                let f1Unread = f1.unreadArticles.count
                let f2Unread = f2.unreadArticles.count
                if f1Unread != f2Unread {
                    return f1Unread > f2Unread
                }
                return f1.displayTitle.lowercased() < f2.displayTitle.lowercased()
            }

            if self.refreshView.isRefreshing { self.refreshView.endRefreshing() }

            self.loadingView.removeFromSuperview()
            self.onboardingView.removeFromSuperview()
            let filteredFeeds = sortedFeeds.filter {
                return $0.title != NSLocalizedString("AppDelegate_UnreadFeed_Title", comment: "")
            }
            if filteredFeeds.isEmpty && (tag == nil || tag?.isEmpty == true) {
                self.view.addSubview(self.onboardingView)
                self.onboardingView.autoCenterInSuperview()
                self.onboardingView.autoMatch(.width,
                                              to: .width,
                                              of: self.view,
                                              withMultiplier: 0.75)
            }

            let oldFeeds = self.feeds
            self.feeds = sortedFeeds
            if oldFeeds != sortedFeeds {
                self.tableView.reloadSections(IndexSet(integer: 0), with: .right)
            } else {
                self.tableView.reloadSections(IndexSet(integer: 0), with: .none)
            }
        }

        if let feeds = feeds, (tag == nil || tag?.isEmpty == true) {
            reloadWithFeeds(feeds)
        }
        _ = self.feedRepository.feeds(matchingTag: tag).then {
            if case let Result.success(feeds) = $0 {
                reloadWithFeeds(feeds)
            }
        }
    }

    @objc fileprivate func didTapAddFeed() {
        guard self.navigationController?.visibleViewController == self else { return }

        self.importFromWeb()
    }

    fileprivate func feedAtIndexPath(_ indexPath: IndexPath) -> Feed {
        return self.feeds[indexPath.row]
    }

    fileprivate func configuredArticleListWithFeeds(_ feed: Feed) -> ArticleListController {
        let articleListController = self.articleListController()
        articleListController.feed = feed
        return articleListController
    }

    fileprivate func showArticleList(_ articleListController: ArticleListController, animated: Bool) {
        self.navigationController?.pushViewController(articleListController, animated: animated)
    }

    internal func showFeed(_ feed: Feed, animated: Bool) -> ArticleListController {
        let al = self.configuredArticleListWithFeeds(feed)
        self.showArticleList(al, animated: animated)
        return al
    }
}

extension FeedsTableViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle

        self.tableView.backgroundColor = self.themeRepository.backgroundColor
        self.tableView.separatorColor = self.themeRepository.textColor
        self.tableView.indicatorStyle = self.themeRepository.scrollIndicatorStyle

        self.searchBar.barStyle = self.themeRepository.barStyle
        self.searchBar.backgroundColor = self.themeRepository.backgroundColor

        self.refreshView.scenebackgroundColor = self.themeRepository.backgroundColor
        self.refreshView.textColor = self.themeRepository.textColor

        self.setNeedsStatusBarAppearanceUpdate()
    }
}

extension FeedsTableViewController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange text: String) {
        self.reload(text)
    }
}

extension FeedsTableViewController: DataSubscriber {
    public func markedArticles(_ articles: [Article], asRead read: Bool) {
        if self.markReadFuture == nil {
            self.reload(self.searchBar.text)
        }
    }

    public func deletedArticle(_ article: Article) {
        self.reload(self.searchBar.text)
    }

    public func deletedFeed(_ feed: Feed, feedsLeft: Int) {
        self.reload(self.searchBar.text)
    }

    public func willUpdateFeeds() {
        self.updateBar.isHidden = false
        self.updateBar.progress = 0
        if !self.refreshView.isRefreshing {
            self.refreshView.beginRefreshing()
        }
    }

    public func didUpdateFeedsProgress(_ finished: Int, total: Int) {
        self.updateBar.setProgress(Float(finished) / Float(total), animated: true)
    }

    public func didUpdateFeeds(_ feeds: [Feed]) {
        self.updateBar.isHidden = true
        if self.refreshView.isRefreshing {
            self.refreshView.endRefreshing()
        }
        self.refreshView.endRefreshing()
        self.reload(self.searchBar.text, feeds: feeds)
    }
}

extension FeedsTableViewController: BreakOutToRefreshDelegate, UIScrollViewDelegate {
    public func refreshViewDidRefresh(_ refreshView: BreakOutToRefreshView) {
        self.feedRepository.updateFeeds({feeds, errors in
            if !errors.isEmpty {
                let alertTitle = NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Title", comment: "")

                let messageString = errors.filter({$0.userInfo["feedTitle"] != nil}).map({(error) -> (String) in
                    let title = error.userInfo["feedTitle"]!
                    let failureReason = error.localizedFailureReason ?? error.localizedDescription
                    return "\(title): \(failureReason)"
                }).joined(separator: "\n")

                let alertMessage = messageString
                self.notificationView.display(alertTitle, message: alertMessage)
            }
        })
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.refreshView.scrollViewWillBeginDragging(scrollView)
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            refreshView.scrollViewWillEndDragging(scrollView,
                withVelocity: velocity,
                targetContentOffset: targetContentOffset)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        refreshView.scrollViewDidScroll(scrollView)
    }
}

extension FeedsTableViewController: UIViewControllerPreviewingDelegate {
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
        viewControllerForLocation location: CGPoint) -> UIViewController? {
            if let indexPath = self.tableView.indexPathForRow(at: location) {
                let feed = self.feedAtIndexPath(indexPath)
                return configuredArticleListWithFeeds(feed)
            }
            return nil
    }

    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
        commit viewControllerToCommit: UIViewController) {
            if let articleController = viewControllerToCommit as? ArticleListController {
                self.showArticleList(articleController, animated: true)
            }
    }
}

extension FeedsTableViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.feeds.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let feed = self.feedAtIndexPath(indexPath)
        let cellTypeToUse = (feed.unreadArticles.isEmpty ? "unread": "read")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.

        if let cell = tableView.dequeueReusableCell(withIdentifier: cellTypeToUse,
                                                    for: indexPath) as? FeedTableCell {
                cell.feed = feed
                cell.themeRepository = self.themeRepository
                return cell
        }
        return UITableViewCell()
    }
}

extension FeedsTableViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        _ = self.showFeed(self.feedAtIndexPath(indexPath), animated: true)
    }

    @objc(tableView:canEditRowAtIndexPath:) public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    @objc(tableView:commitEditingStyle:forRowAtIndexPath:) public func tableView(_ tableView: UITableView,
        commit editingStyle: UITableViewCellEditingStyle,
        forRowAt indexPath: IndexPath) {}

    public func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let delete = UITableViewRowAction(style: .default, title: deleteTitle) {(_, indexPath: IndexPath!) in
                let feed = self.feedAtIndexPath(indexPath)
                let confirmDelete = NSLocalizedString("Generic_ConfirmDelete", comment: "")
                let deleteAlertTitle = NSString.localizedStringWithFormat(confirmDelete as NSString,
                                                                          feed.displayTitle) as String
                let alert = UIAlertController(title: deleteAlertTitle, message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: deleteTitle, style: .destructive) { _ in
                    self.feeds = self.feeds.filter { $0 != feed }
                    _ = self.feedRepository.deleteFeed(feed)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    self.dismiss(animated: true, completion: nil)
                })
                let cancelTitle = NSLocalizedString("Generic_Cancel", comment: "")
                alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
                    self.dismiss(animated: true, completion: nil)
                    tableView.reloadRows(at: [indexPath], with: .right)
                })
                self.present(alert, animated: true, completion: nil)
            }

            let readTitle = NSLocalizedString("FeedsTableViewController_Table_EditAction_MarkRead", comment: "")
            let markRead = UITableViewRowAction(style: .normal, title: readTitle) {_, indexPath in
                let feed = self.feedAtIndexPath(indexPath)
                self.markReadFuture = self.feedRepository.markFeedAsRead(feed)
                _ = self.markReadFuture!.then { _ in
                    self.reload(self.searchBar.text)
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                    self.markReadFuture = nil
                }
            }

            let editTitle = NSLocalizedString("Generic_Edit", comment: "")
            let edit = UITableViewRowAction(style: .normal, title: editTitle) {_, indexPath in
                let feed = self.feedAtIndexPath(indexPath)
                let feedViewController = self.feedViewController()
                feedViewController.feed = feed
                self.present(UINavigationController(rootViewController: feedViewController),
                    animated: true, completion: nil)
            }
            edit.backgroundColor = UIColor.blue
            let feed = self.feedAtIndexPath(indexPath)
            let shareTitle = NSLocalizedString("Generic_Share", comment: "")
            let share = UITableViewRowAction(style: .normal, title: shareTitle) {_ in
                let shareSheet = UIActivityViewController(activityItems: [feed.url], applicationActivities: nil)
                self.present(shareSheet, animated: true, completion: nil)
            }
            share.backgroundColor = UIColor.darkGreen()
            return [delete, markRead, edit, share]
    }
}

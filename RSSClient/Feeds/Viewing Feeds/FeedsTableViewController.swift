import UIKit
import Ra
import CBGPromise
import Result
import rNewsKit

public final class FeedsTableViewController: UIViewController, Injectable {
    public lazy var tableView: UITableView = {
        let tableView = self.tableViewController.tableView!
        tableView.tableHeaderView = self.searchBar
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.translatesAutoresizingMaskIntoConstraints = false
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

    public lazy var onboardingView: ExplanationView = {
        let view = ExplanationView(forAutoLayout: ())
        view.title = NSLocalizedString("FeedsTableViewController_Onboarding_Title", comment: "")
        view.detail = NSLocalizedString("FeedsTableViewController_Onboarding_Detail", comment: "")
        view.themeRepository = self.themeRepository
        return view
    }()

    public private(set) lazy var refreshControl: RefreshControl = {
        return RefreshControl(
            notificationCenter: NotificationCenter.default,
            scrollView: self.tableView,
            mainQueue: self.mainQueue,
            themeRepository: self.themeRepository,
            settingsRepository: self.settingsRepository,
            refresher: self,
            lowPowerDiviner: ProcessInfo.processInfo
        )
    }()

    fileprivate lazy var feedsDeleSource: FeedsDeleSource = {
        return FeedsDeleSource(
            tableView: self.tableView,
            feedsSource: self,
            themeRepository: self.themeRepository,
            navigationController: self.navigationController!,
            articleListController: self.articleListController
        )
    }()

    public let loadingView = ActivityIndicator(forAutoLayout: ())
    public fileprivate(set) var feeds: [Feed] = []
    private let tableViewController = UITableViewController(style: .plain)
    private var menuTopOffset: NSLayoutConstraint!
    public let notificationView = NotificationView(forAutoLayout: ())

    fileprivate let feedRepository: DatabaseUseCase
    fileprivate let themeRepository: ThemeRepository
    fileprivate let settingsRepository: SettingsRepository
    fileprivate let mainQueue: OperationQueue

    fileprivate let findFeedViewController: (Void) -> FindFeedViewController
    fileprivate let feedViewController: (Void) -> FeedViewController
    fileprivate let settingsViewController: (Void) -> SettingsViewController
    fileprivate let articleListController: (Void) -> ArticleListController

    fileprivate var markReadFuture: Future<Result<Int, RNewsError>>? = nil

    // swiftlint:disable function_parameter_count
    public init(feedRepository: DatabaseUseCase,
                themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                mainQueue: OperationQueue,
                findFeedViewController: @escaping (Void) -> FindFeedViewController,
                feedViewController: @escaping (Void) -> FeedViewController,
                settingsViewController: @escaping (Void) -> SettingsViewController,
                articleListController: @escaping (Void) -> ArticleListController
        ) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.mainQueue = mainQueue
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
            mainQueue: injector.create(string: kMainQueue) as! OperationQueue,
            findFeedViewController: {injector.create(kind: FindFeedViewController.self)!},
            feedViewController: {injector.create(kind: FeedViewController.self)!},
            settingsViewController: {injector.create(kind: SettingsViewController.self)!},
            articleListController: {injector.create(kind: ArticleListController.self)!}
        )
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.addChildViewController(self.tableViewController)
        self.tableView.keyboardDismissMode = .onDrag
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)
        self.tableView.delegate = self.feedsDeleSource
        self.tableView.dataSource = self.feedsDeleSource
        self.feedsDeleSource.scrollViewDelegate = self.refreshControl
        self.refreshControl.updateSize(self.view.bounds.size)

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

        self.registerForPreviewing(with: self.feedsDeleSource, sourceView: self.tableView)

        self.feedRepository.addSubscriber(self)
        self.themeRepository.addSubscriber(self)
        self.reload(self.searchBar.text)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refreshControl.updateSize(self.view.bounds.size)
    }

    public override func viewWillTransition(to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)

            self.refreshControl.updateSize(size)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.refreshControl.endRefreshing()
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
            nc.modalPresentationStyle = .popover
            nc.preferredContentSize = CGSize(width: 600, height: 800)
            self.present(nc, animated: true) {
                nc.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
            }
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

            self.refreshControl.endRefreshing()

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

    internal func showFeed(_ feed: Feed, animated: Bool) -> ArticleListController {
        let articleListController = self.articleListController()
        articleListController.feed = feed
        self.navigationController?.pushViewController(articleListController, animated: animated)
        return articleListController
    }
}

extension FeedsTableViewController: FeedsSource {
    public func deleteFeed(feed: Feed) -> Future<Bool> {
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let confirmDelete = NSLocalizedString("Generic_ConfirmDelete", comment: "")
        let deleteAlertTitle = NSString.localizedStringWithFormat(confirmDelete as NSString,
                                                                  feed.displayTitle) as String
        let alert = UIAlertController(title: deleteAlertTitle, message: "", preferredStyle: .alert)
        let promise = Promise<Bool>()
        alert.addAction(UIAlertAction(title: deleteTitle, style: .destructive) { _ in
            self.feeds = self.feeds.filter { $0 != feed }
            _ = self.feedRepository.deleteFeed(feed)
            self.dismiss(animated: true, completion: nil)
            promise.resolve(true)
        })
        let cancelTitle = NSLocalizedString("Generic_Cancel", comment: "")
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
            promise.resolve(false)
        })
        self.present(alert, animated: true, completion: nil)
        return promise.future
    }

    public func markRead(feed: Feed) -> Future<Void> {
        self.markReadFuture = self.feedRepository.markFeedAsRead(feed)
        return self.markReadFuture!.map { _ -> Void in
            self.mainQueue.addOperation {
                self.reload(self.searchBar.text)
                self.markReadFuture = nil
            }
        }
    }

    public func editFeed(feed: Feed) {
        let feedViewController = self.feedViewController()
        feedViewController.feed = feed
        self.present(UINavigationController(rootViewController: feedViewController),
                     animated: true, completion: nil)
    }

    public func shareFeed(feed: Feed) {
        let shareSheet = UIActivityViewController(activityItems: [feed.url], applicationActivities: nil)
        self.present(shareSheet, animated: true, completion: nil)
    }
}

extension FeedsTableViewController: Refresher {
    public func refresh() {
        self.feedRepository.updateFeeds({feeds, errors in
            if !errors.isEmpty {
                let alertTitle = NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Title", comment: "")

                let messageString: String
                if errors.count == 1, let error = errors.first, error.userInfo["feedTitle"] == nil {
                    messageString = error.localizedDescription
                } else {
                    messageString = errors.filter({$0.userInfo["feedTitle"] != nil}).map({(error) -> (String) in
                        let title = error.userInfo["feedTitle"]!
                        let failureReason = error.localizedFailureReason ?? error.localizedDescription
                        return "\(title): \(failureReason)"
                    }).joined(separator: "\n")
                }

                let alertMessage = messageString
                self.notificationView.display(alertTitle, message: alertMessage)
            }
        })
    }
}

extension FeedsTableViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: themeRepository.textColor
        ]

        self.tableView.backgroundColor = self.themeRepository.backgroundColor
        self.tableView.separatorColor = self.themeRepository.textColor
        self.tableView.indicatorStyle = self.themeRepository.scrollIndicatorStyle

        self.searchBar.barStyle = self.themeRepository.barStyle
        self.searchBar.backgroundColor = self.themeRepository.backgroundColor

        self.setNeedsStatusBarAppearanceUpdate()
    }
}

extension FeedsTableViewController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange text: String) { self.reload(text) }
}

extension FeedsTableViewController: DataSubscriber {
    public func markedArticles(_ articles: [Article], asRead read: Bool) {
        if self.markReadFuture == nil {
            self.reload(self.searchBar.text)
        }
    }

    public func deletedArticle(_ article: Article) { self.reload(self.searchBar.text) }

    public func deletedFeed(_ feed: Feed, feedsLeft: Int) { self.reload(self.searchBar.text) }

    public func willUpdateFeeds() {
        self.updateBar.isHidden = false
        self.updateBar.progress = 0
        self.refreshControl.beginRefreshing()
    }

    public func didUpdateFeedsProgress(_ finished: Int, total: Int) {
        self.updateBar.setProgress(Float(finished) / Float(total), animated: true)
    }

    public func didUpdateFeeds(_ feeds: [Feed]) {
        self.updateBar.isHidden = true
        self.refreshControl.endRefreshing(force: true)
        self.reload(self.searchBar.text, feeds: feeds)
    }
}

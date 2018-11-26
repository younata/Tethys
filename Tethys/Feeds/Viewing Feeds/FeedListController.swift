import UIKit
import CBGPromise
import Result
import TethysKit

public final class FeedListController: UIViewController {
    public private(set) lazy var tableView: UITableView = {
        let tableView = self.tableViewController.tableView!
        tableView.tableHeaderView = UIView()
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    public lazy var updateBar: UIProgressView = {
        let updateBar = UIProgressView(progressViewStyle: .default)
        updateBar.translatesAutoresizingMaskIntoConstraints = false
        updateBar.progressTintColor = UIColor.darkGreen
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
            mainQueue: self.mainQueue,
            articleListController: self.articleListController
        )
    }()

    public let loadingView = ActivityIndicator(forAutoLayout: ())
    public fileprivate(set) var feeds: [Feed] = []
    private let tableViewController = UITableViewController(style: .plain)
    private var menuTopOffset: NSLayoutConstraint!
    public let notificationView = NotificationView(forAutoLayout: ())

    fileprivate let feedService: FeedService
    fileprivate let themeRepository: ThemeRepository
    fileprivate let settingsRepository: SettingsRepository
    fileprivate let mainQueue: OperationQueue

    fileprivate let findFeedViewController: () -> FindFeedViewController
    fileprivate let feedViewController: (Feed) -> FeedViewController
    fileprivate let settingsViewController: () -> SettingsViewController
    fileprivate let articleListController: (Feed) -> ArticleListController

    fileprivate var markReadFuture: Future<Result<Int, TethysError>>?

    public init(feedService: FeedService,
                themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                mainQueue: OperationQueue,
                findFeedViewController: @escaping () -> FindFeedViewController,
                feedViewController: @escaping (Feed) -> FeedViewController,
                settingsViewController: @escaping () -> SettingsViewController,
                articleListController: @escaping (Feed) -> ArticleListController
        ) {
        self.feedService = feedService
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.mainQueue = mainQueue
        self.findFeedViewController = findFeedViewController
        self.feedViewController = feedViewController
        self.settingsViewController = settingsViewController
        self.articleListController = articleListController
        super.init(nibName: nil, bundle: nil)
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
        if self.updateBar.superview != nil {
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
                                        action: #selector(FeedListController.didTapAddFeed))
        self.navigationItem.rightBarButtonItems = [addButton, self.tableViewController.editButtonItem]

        let settingsTitle = NSLocalizedString("SettingsViewController_Title", comment: "")
        let settingsButton = UIBarButtonItem(title: settingsTitle,
            style: .plain,
            target: self,
            action: #selector(FeedListController.presentSettings))
        self.navigationItem.leftBarButtonItem = settingsButton

        self.navigationItem.title = NSLocalizedString("FeedsTableViewController_Title", comment: "")

        self.registerForPreviewing(with: self.feedsDeleSource, sourceView: self.tableView)

        self.themeRepository.addSubscriber(self)
        self.refreshControl.beginRefreshing()
        self.reload()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refreshControl.updateSize(self.view.bounds.size)
        self.navigationController?.setToolbarHidden(true, animated: true)
    }

    public override func viewWillTransition(
        to size: CGSize,
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
            UIKeyCommand(input: "i", modifierFlags: .command,
                         action: #selector(FeedListController.importFromWeb)),
            UIKeyCommand(input: ",", modifierFlags: .command,
                         action: #selector(FeedListController.presentSettings))
            ]
        let discoverabilityTitles = [
            NSLocalizedString("FeedsTableViewController_Command_ImportWeb", comment: ""),
            NSLocalizedString("FeedsTableViewController_Command_Settings", comment: "")
        ]
        commands.enumerated().forEach { idx, cmd in cmd.discoverabilityTitle = discoverabilityTitles[idx] }
        return commands
    }

    // MARK: - Private/Internal

    internal func importFromWeb() {
        self.presentController(self.findFeedViewController(), from: self.navigationItem.rightBarButtonItem)
    }

    @objc fileprivate func presentSettings() {
        self.presentController(self.settingsViewController(), from: self.navigationItem.leftBarButtonItem)
    }

    private func presentController(_ viewController: UIViewController, from: UIBarButtonItem?) {
        let nc = UINavigationController(rootViewController: viewController)
        if UIDevice.current.userInterfaceIdiom == .pad {
            nc.modalPresentationStyle = .popover
            nc.preferredContentSize = CGSize(width: 600, height: 800)
            nc.popoverPresentationController?.barButtonItem = from
            self.present(nc, animated: true, completion: nil)
        } else {
            self.present(nc, animated: true, completion: nil)
        }
    }

    private func showLoadingView(_ message: String) {
        self.loadingView.configure(message: message)
        self.view.addSubview(self.loadingView)
        self.loadingView.autoPinEdgesToSuperviewEdges()
    }

    fileprivate func reload() {
        let reloadWithFeeds: ([Feed]) -> Void = {feeds in
            self.refreshControl.endRefreshing()

            self.loadingView.removeFromSuperview()
            self.onboardingView.removeFromSuperview()
            let filteredFeeds = feeds.filter {
                return $0.title != NSLocalizedString("AppDelegate_UnreadFeed_Title", comment: "")
            }
            if filteredFeeds.isEmpty {
                self.view.addSubview(self.onboardingView)
                self.onboardingView.autoCenterInSuperview()
                self.onboardingView.autoMatch(.width,
                                              to: .width,
                                              of: self.view,
                                              withMultiplier: 0.75)
            }

            let oldFeeds = self.feeds
            self.feeds = feeds
            if oldFeeds != feeds {
                self.tableView.reloadSections(IndexSet(integer: 0), with: .right)
            } else {
                self.tableView.reloadSections(IndexSet(integer: 0), with: .none)
            }
        }

        self.feedService.feeds().then {
            switch $0 {
            case .success(let feeds):
                reloadWithFeeds(Array(feeds))
            case .failure(let error):
                self.show(
                    error: error,
                    title: NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Title", comment: "")
                )
            }
        }
    }

    @objc fileprivate func didTapAddFeed() {
        guard self.navigationController?.visibleViewController == self else { return }
        self.importFromWeb()
    }

    internal func showFeed(_ feed: Feed, animated: Bool) -> ArticleListController {
        let articleListController = self.articleListController(feed)
        self.navigationController?.pushViewController(articleListController, animated: animated)
        return articleListController
    }

    fileprivate func show(error: TethysError, title: String) {
        self.notificationView.display(title, message: error.localizedDescription)

    }
}

extension FeedListController: FeedsSource {
    public func deleteFeed(feed: Feed) -> Future<Bool> {
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let confirmDelete = NSLocalizedString("Generic_ConfirmDelete", comment: "")
        let deleteAlertTitle = NSString.localizedStringWithFormat(confirmDelete as NSString,
                                                                  feed.displayTitle) as String
        let alert = UIAlertController(title: deleteAlertTitle, message: "", preferredStyle: .alert)
        let promise = Promise<Bool>()
        alert.addAction(UIAlertAction(title: deleteTitle, style: .destructive) { _ in
            self.feeds = self.feeds.filter { $0 != feed }
            self.dismiss(animated: true, completion: nil)
            self.feedService.remove(feed: feed).then { result in
                switch result {
                case .success:
                    promise.resolve(true)
                case .failure(let error):
                    self.show(
                        error: error,
                        title: NSLocalizedString("FeedsTableViewController_Loading_Deleting_Feed_Error", comment: "")
                    )
                    promise.resolve(false)
                }
            }
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
        return self.feedService.readAll(of: feed).map { result -> Void in
            switch result {
            case .success:
                break
            case .failure(let error):
                self.show(
                    error: error,
                    title: NSLocalizedString("FeedsTableViewController_Loading_Marking_Feed_Error", comment: "")
                )
            }
        }
    }

    public func editFeed(feed: Feed) {
        self.present(UINavigationController(rootViewController: self.feedViewController(feed)),
                     animated: true, completion: nil)
    }

    public func shareFeed(feed: Feed) {
        let shareSheet = URLShareSheet(
            url: feed.url,
            themeRepository: self.themeRepository,
            activityItems: [feed.url],
            applicationActivities: nil
        )
        self.present(shareSheet, animated: true, completion: nil)
    }
}

extension FeedListController: Refresher {
    public func refresh() {
        self.reload()
    }
}

extension FeedListController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: themeRepository.textColor
        ]

        self.tableView.backgroundColor = self.themeRepository.backgroundColor
        self.tableView.separatorColor = self.themeRepository.textColor
        self.tableView.indicatorStyle = self.themeRepository.scrollIndicatorStyle

        self.setNeedsStatusBarAppearanceUpdate()
    }
}

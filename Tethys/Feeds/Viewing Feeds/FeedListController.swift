import UIKit
import CBGPromise
import Result
import TethysKit

public final class FeedListController: UIViewController {
    public private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(forAutoLayout: ())
        tableView.tableHeaderView = UIView()
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        return tableView
    }()

    public lazy var onboardingView: ExplanationView = {
        let view = ExplanationView(frame: .zero)
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

    public fileprivate(set) var feeds: [Feed] = []
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

        self.tableView.keyboardDismissMode = .onDrag
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: .zero)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.register(FeedTableCell.self, forCellReuseIdentifier: "read")
        self.tableView.register(FeedTableCell.self, forCellReuseIdentifier: "unread")
        self.refreshControl.updateSize(self.view.bounds.size)

        self.themeRepository.addSubscriber(self.notificationView)
        self.navigationController?.navigationBar.addSubview(self.notificationView)
        self.notificationView.autoPinEdge(toSuperviewMargin: .trailing)
        self.notificationView.autoPinEdge(toSuperviewMargin: .leading)
        self.notificationView.autoPinEdge(.top, to: .bottom, of: self.navigationController!.navigationBar)

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self,
                                        action: #selector(FeedListController.didTapAddFeed))
        self.navigationItem.rightBarButtonItems = [addButton, self.editButtonItem]

        let settingsButton = UIBarButtonItem(image: Image(named: "settings"), style: .plain,
                                             target: self, action: #selector(FeedListController.presentSettings))
        self.navigationItem.leftBarButtonItem = settingsButton
        self.navigationItem.title = NSLocalizedString("FeedsTableViewController_Title", comment: "")
        self.registerForPreviewing(with: self, sourceView: self.tableView)

        self.themeRepository.addSubscriber(self)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refreshControl.updateSize(self.view.bounds.size)
        self.navigationController?.setToolbarHidden(true, animated: true)
        self.refreshControl.beginRefreshing()
        self.reload()
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
                         action: #selector(FeedListController.presentSettings)),
            UIKeyCommand(input: "r", modifierFlags: .command, action: #selector(FeedListController.reload))
        ]
        let discoverabilityTitles = [
            NSLocalizedString("FeedsTableViewController_Command_ImportWeb", comment: ""),
            NSLocalizedString("FeedsTableViewController_Command_Settings", comment: ""),
            NSLocalizedString("FeedsTableViewController_Command_Reload", comment: "")
        ]
        commands.enumerated().forEach { idx, cmd in cmd.discoverabilityTitle = discoverabilityTitles[idx] }
        return commands
    }

    @objc internal func importFromWeb() {
        self.show(controller: self.findFeedViewController(), from: self.navigationItem.rightBarButtonItem)
    }

    @objc fileprivate func presentSettings() {
        self.show(controller: self.settingsViewController(), from: self.navigationItem.leftBarButtonItem)
    }

    @objc fileprivate func reload() {
        let reloadWithFeeds: ([Feed]) -> Void = {feeds in
            self.refreshControl.endRefreshing(force: true)

            self.onboardingView.removeFromSuperview()
            if feeds.isEmpty {
                self.view.addSubview(self.onboardingView)
                self.onboardingView.autoCenterInSuperview()
                self.onboardingView.autoMatch(.width,
                                              to: .width,
                                              of: self.view,
                                              withMultiplier: 0.75)
            }

            let oldFeeds = self.feeds
            self.feeds = feeds
            guard oldFeeds != feeds else { return }
            self.tableView.reloadSections(IndexSet(integer: 0), with: oldFeeds.isEmpty ? .none : .right)
        }

        self.feedService.feeds().then {
            let errorTitle = NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Title", comment: "")
            self.unwrap(result: $0, errorTitle: errorTitle) { reloadWithFeeds(Array($0)) }
        }
    }

    private func show(controller: UIViewController, from: UIBarButtonItem?) {
        self.navigationController?.pushViewController(controller, animated: true)
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

    fileprivate func unwrap<T>(result: Result<T, TethysError>, errorTitle: String, onSuccess: (T) -> Void) {
        switch result {
        case .success(let value):
            onSuccess(value)
        case .failure(let error):
            self.notificationView.display(errorTitle, message: error.localizedDescription)
        }
    }

    fileprivate func deleteFeed(feed: Feed, indexPath: IndexPath?) {
        self.feedService.remove(feed: feed).then { result in
            let errorTitle = NSLocalizedString("FeedsTableViewController_Loading_Deleting_Feed_Error", comment: "")
            self.unwrap(result: result, errorTitle: errorTitle) {
                self.feeds = self.feeds.filter { $0 != feed }
                if let indexPath = indexPath {
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                } else {
                    self.tableView.reloadData()
                }
            }
        }
    }

    fileprivate func markRead(feed: Feed, indexPath: IndexPath?) {
        self.feedService.readAll(of: feed).then { result in
            let errorTitle = NSLocalizedString("FeedsTableViewController_Loading_Marking_Feed_Error", comment: "")
            self.unwrap(result: result, errorTitle: errorTitle) {
                if let indexPath = indexPath {
                    self.tableView.reloadRows(at: [indexPath], with: .automatic)
                } else {
                    self.tableView.reloadData()
                }
            }
        }
    }

    fileprivate func editFeed(feed: Feed, view: UIView?) {
        let controller = self.feedViewController(feed)
        self.navigationController?.pushViewController(controller, animated: true)
    }

    fileprivate func shareFeed(feed: Feed) {
        let shareSheet = URLShareSheet(
            url: feed.url,
            themeRepository: self.themeRepository,
            activityItems: [feed.url],
            applicationActivities: nil
        )
        self.present(shareSheet, animated: true, completion: nil)
    }

    fileprivate func feed(indexPath: IndexPath) -> Feed { return self.feeds[indexPath.row] }
}

extension FeedListController: UIViewControllerPreviewingDelegate {
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                                  viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = self.tableView.indexPathForRow(at: location) else { return nil }
        let feed = self.feeds[indexPath.row]
        let articleListController = self.articleListController(feed)
        articleListController._previewActionItems = self.articleListPreviewItems(feed: feed)
        return articleListController
    }

    private func articleListPreviewItems(feed: Feed) -> [UIPreviewAction] {
        let readTitle = NSLocalizedString("FeedsTableViewController_PreviewItem_MarkRead", comment: "")
        let markRead = UIPreviewAction(title: readTitle, style: .default) { _, _  in
            self.markRead(feed: feed, indexPath: nil)
        }
        let editTitle = NSLocalizedString("Generic_Edit", comment: "")
        let edit = UIPreviewAction(title: editTitle, style: .default) { _, _  in
            self.editFeed(feed: feed, view: nil)
        }
        let shareTitle = NSLocalizedString("Generic_Share", comment: "")
        let share = UIPreviewAction(title: shareTitle, style: .default) { _, _  in
            self.shareFeed(feed: feed)
        }
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UIPreviewAction(title: deleteTitle, style: .destructive) { _, _  in
            self.deleteFeed(feed: feed, indexPath: nil)
        }
        return [markRead, edit, share, delete]
    }

    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                                  commit viewControllerToCommit: UIViewController) {
        guard let articleController = viewControllerToCommit as? ArticleListController else { return }
        self.navigationController?.pushViewController(articleController, animated: true)
    }
}

extension FeedListController: Refresher {
    public func refresh() { self.reload() }
}

extension FeedListController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: themeRepository.textColor
        ]

        self.tableView.backgroundColor = self.themeRepository.backgroundColor
        self.tableView.separatorColor = self.themeRepository.textColor
        self.tableView.indicatorStyle = self.themeRepository.scrollIndicatorStyle

        self.setNeedsStatusBarAppearanceUpdate()
    }
}

extension FeedListController: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.feeds.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let feed = self.feed(indexPath: indexPath)
        let cellTypeToUse = (feed.unreadCount > 0 ? "unread": "read")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.

        if let cell = tableView.dequeueReusableCell(withIdentifier: cellTypeToUse, for: indexPath) as? FeedTableCell {
            cell.feed = feed
            cell.themeRepository = self.themeRepository
            return cell
        }
        return UITableViewCell()
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let feed = self.feed(indexPath: indexPath)
        self.navigationController?.pushViewController(self.articleListController(feed), animated: true)
    }

    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { return true }

    public func tableView(_ tableView: UITableView,
                          commit editingStyle: UITableViewCell.EditingStyle,
                          forRowAt indexPath: IndexPath) {}

    public func tableView(_ tableView: UITableView,
                          editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UITableViewRowAction(style: .default, title: deleteTitle) {(_, indexPath: IndexPath!) in
            self.deleteFeed(feed: self.feed(indexPath: indexPath), indexPath: indexPath)
        }

        let readTitle = NSLocalizedString("FeedsTableViewController_Table_EditAction_MarkRead", comment: "")
        let markRead = UITableViewRowAction(style: .normal, title: readTitle) {_, indexPath in
            self.markRead(feed: self.feed(indexPath: indexPath), indexPath: indexPath)
        }

        let editTitle = NSLocalizedString("Generic_Edit", comment: "")
        let edit = UITableViewRowAction(style: .normal, title: editTitle) {_, indexPath in
            self.editFeed(feed: self.feed(indexPath: indexPath), view: tableView.cellForRow(at: indexPath))
        }
        edit.backgroundColor = UIColor.blue
        let shareTitle = NSLocalizedString("Generic_Share", comment: "")
        let share = UITableViewRowAction(style: .normal, title: shareTitle) {_, _  in
            self.shareFeed(feed: self.feed(indexPath: indexPath))
        }
        share.backgroundColor = UIColor.darkGreen
        return [delete, markRead, edit, share]
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.refreshControl.scrollViewWillBeginDragging(scrollView)
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                          withVelocity velocity: CGPoint,
                                          targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        self.refreshControl.scrollViewWillEndDragging(scrollView, withVelocity: velocity,
                                                      targetContentOffset: targetContentOffset)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) { self.refreshControl.scrollViewDidScroll(scrollView) }
}

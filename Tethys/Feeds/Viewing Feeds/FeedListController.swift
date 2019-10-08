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
        view.accessibilityLabel = NSLocalizedString("FeedsTableViewController_Onboarding_AccessibilityLabel",
                                                    comment: "")
        view.accessibilityValue = NSLocalizedString("FeedsTableViewController_Onboarding_AccessibilityValue",
                                                    comment: "")
        return view
    }()

    public private(set) lazy var refreshControl: RefreshControl = {
        return RefreshControl(
            notificationCenter: NotificationCenter.default,
            scrollView: self.tableView,
            mainQueue: self.mainQueue,
            settingsRepository: self.settingsRepository,
            refresher: self,
            lowPowerDiviner: ProcessInfo.processInfo
        )
    }()

    public fileprivate(set) var feeds: [Feed] = []
    private var menuTopOffset: NSLayoutConstraint!
    public let notificationView = NotificationView(forAutoLayout: ())

    fileprivate let feedService: FeedService
    fileprivate let settingsRepository: SettingsRepository
    fileprivate let mainQueue: OperationQueue
    fileprivate let notificationCenter: NotificationCenter

    fileprivate let findFeedViewController: () -> FindFeedViewController
    fileprivate let feedViewController: (Feed) -> FeedViewController
    fileprivate let settingsViewController: () -> SettingsViewController
    fileprivate let articleListController: (Feed) -> ArticleListController

    public init(feedService: FeedService,
                settingsRepository: SettingsRepository,
                mainQueue: OperationQueue,
                notificationCenter: NotificationCenter,
                findFeedViewController: @escaping () -> FindFeedViewController,
                feedViewController: @escaping (Feed) -> FeedViewController,
                settingsViewController: @escaping () -> SettingsViewController,
                articleListController: @escaping (Feed) -> ArticleListController
        ) {
        self.feedService = feedService
        self.settingsRepository = settingsRepository
        self.mainQueue = mainQueue
        self.notificationCenter = notificationCenter
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

        self.navigationController?.navigationBar.addSubview(self.notificationView)
        self.notificationView.autoPinEdge(toSuperviewMargin: .trailing)
        self.notificationView.autoPinEdge(toSuperviewMargin: .leading)
        self.notificationView.autoPinEdge(.top, to: .bottom, of: self.navigationController!.navigationBar)

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self,
                                        action: #selector(FeedListController.didTapAddFeed))
        addButton.accessibilityLabel = NSLocalizedString("FeedsTableViewController_Accessibility_AddFeed", comment: "")
        self.navigationItem.rightBarButtonItems = [addButton, self.editButtonItem]

        let settingsButton = UIBarButtonItem(image: Image(named: "settings"), style: .plain,
                                             target: self, action: #selector(FeedListController.presentSettings))
        settingsButton.accessibilityLabel = NSLocalizedString("FeedsTableViewController_Accessibility_Settings",
                                                              comment: "")
        self.navigationItem.leftBarButtonItem = settingsButton
        self.navigationItem.title = NSLocalizedString("FeedsTableViewController_Title", comment: "")

        self.applyTheme()

        self.notificationCenter.addObserver(self, selector: #selector(FeedListController.reloadFrom(notification:)),
                                            name: Notifications.reloadUI, object: nil)

        self.mainQueue.addOperation {
            self.refreshControl.beginRefreshing()
            self.reload()
        }
    }

    private func applyTheme() {
        self.tableView.backgroundColor = Theme.backgroundColor
        self.tableView.separatorColor = Theme.separatorColor
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

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        self.refreshControl.updateTheme()
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

    @objc private func reloadFrom(notification: Notification) {
        guard notification.object as? NSObject != self else { return }

        self.reload(force: true)
    }

    @objc fileprivate func reload(force: Bool = false) {
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
            guard force || oldFeeds != feeds else { return }
            self.tableView.reloadSections(IndexSet(integer: 0), with: oldFeeds.isEmpty ? .none : .right)
        }

        self.feedService.feeds().then {
            let errorTitle = NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Title", comment: "")
            self.unwrap(
                result: $0,
                errorTitle: errorTitle,
                onSuccess: { reloadWithFeeds(Array($0)) },
                onError: { }
            )
        }
    }

    private func show(controller: UIViewController, from item: UIBarButtonItem?) {
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .pageSheet

        self.present(navigationController, animated: true, completion: nil)
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

    fileprivate func unwrap<T>(result: Result<T, TethysError>, errorTitle: String,
                               onSuccess: (T) -> Void, onError: () -> Void) {
        switch result {
        case .success(let value):
            onSuccess(value)
        case .failure(let error):
            self.notificationView.display(errorTitle, message: error.localizedDescription)
            onError()
        }
    }

    fileprivate func deleteFeed(feed: Feed, indexPath: IndexPath?, completionHandler: ((Bool) -> Void)? = nil) {
        self.feedService.remove(feed: feed).then { result in
            let errorTitle = NSLocalizedString("FeedsTableViewController_Loading_Deleting_Feed_Error", comment: "")
            self.unwrap(
                result: result,
                errorTitle: errorTitle,
                onSuccess: {
                    self.feeds = self.feeds.filter { $0 != feed }
                    if let indexPath = indexPath {
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    } else {
                        self.tableView.reloadData()
                    }
                    completionHandler?(true)
                },
                onError: {
                    completionHandler?(false)
                }
            )
        }
    }

    fileprivate func markRead(feed: Feed, indexPath: IndexPath?, completionHandler: ((Bool) -> Void)? = nil) {
        self.feedService.readAll(of: feed).then { result in
            let errorTitle = NSLocalizedString("FeedsTableViewController_Loading_Marking_Feed_Error", comment: "")
            self.unwrap(
                result: result,
                errorTitle: errorTitle,
                onSuccess: {
                    if let indexPath = indexPath {
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    } else {
                        self.tableView.reloadData()
                    }

                    self.notificationCenter.post(name: Notifications.reloadUI, object: self)
                    completionHandler?(true)
            },
                onError: { completionHandler?(false) }
            )
        }
    }

    fileprivate func editFeed(feed: Feed, view: UIView?) {
        let controller = self.feedViewController(feed)
        self.navigationController?.pushViewController(controller, animated: true)
    }

    fileprivate func shareFeed(feed: Feed, view: UIView?) {
        let shareSheet = URLShareSheet(
            url: feed.url,
            activityItems: [feed.url],
            applicationActivities: nil
        )
        shareSheet.popoverPresentationController?.sourceView = view ?? self.navigationController?.navigationBar
        self.present(shareSheet, animated: true, completion: nil)
    }

    fileprivate func feed(indexPath: IndexPath) -> Feed { return self.feeds[indexPath.row] }
}

extension FeedListController: Refresher {
    public func refresh() { self.reload() }
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

    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt
                                                    indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UIContextualAction(style: .destructive, title: deleteTitle, handler: { (_, _, handler) in
            self.deleteFeed(feed: self.feed(indexPath: indexPath), indexPath: indexPath, completionHandler: handler)
        })
        let readTitle = NSLocalizedString("FeedsTableViewController_Table_EditAction_MarkRead", comment: "")
        let markRead = UIContextualAction(style: .normal, title: readTitle) { (_, _, handler) in
            self.markRead(feed: self.feed(indexPath: indexPath), indexPath: indexPath, completionHandler: handler)
        }
        let editTitle = NSLocalizedString("Generic_Edit", comment: "")
        let edit = UIContextualAction(style: .normal, title: editTitle) { (_, view, handler) in
            self.editFeed(feed: self.feed(indexPath: indexPath), view: view)
            handler(true)
        }
        edit.backgroundColor = UIColor.systemBlue
        let shareTitle = NSLocalizedString("Generic_Share", comment: "")
        let share = UIContextualAction(style: .normal, title: shareTitle) { _, view, handler in
            self.shareFeed(feed: self.feed(indexPath: indexPath), view: view)
            handler(true)
        }
        share.backgroundColor = Theme.highlightColor
        let configuration = UISwipeActionsConfiguration(actions: [
            delete, markRead, edit, share
        ])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }

    public func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                          point: CGPoint) -> UIContextMenuConfiguration? {
        let feed = self.feed(indexPath: indexPath)
        return UIContextMenuConfiguration(
            identifier: feed.url as NSURL,
            previewProvider: { [weak self] in return self?.articleListController(feed) },
            actionProvider: { [weak self] elements in
                guard let theSelf = self else { return nil }
                return UIMenu(title: feed.displayTitle, image: feed.image, identifier: nil, options: [],
                              children: elements + theSelf.menuActions(for: feed))
        })
    }

    private func menuActions(for feed: Feed) -> [UIAction] {
        let readTitle = NSLocalizedString("FeedsTableViewController_PreviewItem_MarkRead", comment: "")
        let markRead = UIAction(title: readTitle, image: UIImage(named: "MarkRead")) { [weak self] _ in
            self?.markRead(feed: feed, indexPath: nil)
        }
        let editTitle = NSLocalizedString("Generic_Edit", comment: "")
        let edit = UIAction(title: editTitle) { [weak self] _ in
            self?.editFeed(feed: feed, view: nil)
        }
        let shareTitle = NSLocalizedString("Generic_Share", comment: "")
        let share = UIAction(title: shareTitle, image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            self?.shareFeed(feed: feed, view: nil)
        }
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UIAction(title: deleteTitle, image: UIImage(systemName: "trash")) { [weak self] _ in
            self?.deleteFeed(feed: feed, indexPath: nil)
        }
        return [markRead, edit, share, delete]
    }

    public func tableView(_ tableView: UITableView,
                          willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                          animator: UIContextMenuInteractionCommitAnimating) {
        animator.addCompletion { [weak self] in
            guard let viewController = animator.previewViewController else { return }
            self?.navigationController?.pushViewController(viewController, animated: true)
        }
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

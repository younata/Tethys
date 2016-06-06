import UIKit
import BreakOutToRefresh
import MAKDropDownMenu
import Ra
import CBGPromise
import Result
import rNewsKit

// swiftlint:disable file_length

public class FeedsTableViewController: UIViewController, Injectable {
    public lazy var tableView: UITableView = {
        let tableView = self.tableViewController.tableView
        tableView.tableHeaderView = self.searchBar
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self

        tableView.registerClass(FeedTableCell.self, forCellReuseIdentifier: "read")
        tableView.registerClass(FeedTableCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.

        return tableView
    }()

    public lazy var dropDownMenu: MAKDropDownMenu = {
        let dropDownMenu = MAKDropDownMenu(forAutoLayout: ())
        dropDownMenu.delegate = self
        dropDownMenu.separatorHeight = 1.0 / UIScreen.mainScreen().scale
        dropDownMenu.buttonsInsets = UIEdgeInsets(top: dropDownMenu.separatorHeight, left: 0, bottom: 0, right: 0)
        dropDownMenu.tintColor = UIColor.darkGreenColor()
        dropDownMenu.backgroundColor = UIColor(white: 0.75, alpha: 0.5)
        return dropDownMenu
    }()

    public lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: 320, height: 32))
        searchBar.autocorrectionType = .No
        searchBar.autocapitalizationType = .None
        searchBar.delegate = self
        searchBar.placeholder = NSLocalizedString("FeedsTableViewController_SearchBar_Placeholder", comment: "")
        return searchBar
    }()

    public lazy var updateBar: UIProgressView = {
        let updateBar = UIProgressView(progressViewStyle: .Default)
        updateBar.translatesAutoresizingMaskIntoConstraints = false
        updateBar.progressTintColor = UIColor.darkGreenColor()
        updateBar.trackTintColor = UIColor.clearColor()
        updateBar.hidden = true
        return updateBar
    }()

    public lazy var refreshView: BreakOutToRefreshView = {
        let refreshView = BreakOutToRefreshView(scrollView: self.tableView)
        refreshView.delegate = self
        refreshView.scenebackgroundColor = UIColor.whiteColor()
        refreshView.paddleColor = UIColor.blueColor()
        refreshView.ballColor = UIColor.darkGreenColor()
        refreshView.blockColors = [UIColor.darkGrayColor(), UIColor.grayColor(), UIColor.lightGrayColor()]
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

    private var feeds: [Feed] = []
    private let tableViewController = UITableViewController(style: .Plain)
    private var menuTopOffset: NSLayoutConstraint!

    public let notificationView = NotificationView(forAutoLayout: ())

    private let feedRepository: DatabaseUseCase
    private let themeRepository: ThemeRepository
    private let settingsRepository: SettingsRepository

    private let findFeedViewController: Void -> FindFeedViewController
    private let localImportViewController: Void -> LocalImportViewController
    private let feedViewController: Void -> FeedViewController
    private let queryFeedViewController: Void -> QueryFeedViewController
    private let settingsViewController: Void -> SettingsViewController
    private let articleListController: Void -> ArticleListController

    private var markReadFuture: Future<Result<Int, RNewsError>>? = nil

    // swiftlint:disable function_parameter_count
    public init(feedRepository: DatabaseUseCase,
                themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                findFeedViewController: Void -> FindFeedViewController,
                localImportViewController: Void -> LocalImportViewController,
                feedViewController: Void -> FeedViewController,
                queryFeedViewController: Void -> QueryFeedViewController,
                settingsViewController: Void -> SettingsViewController,
                articleListController: Void -> ArticleListController
        ) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.findFeedViewController = findFeedViewController
        self.localImportViewController = localImportViewController
        self.feedViewController = feedViewController
        self.queryFeedViewController = queryFeedViewController
        self.settingsViewController = settingsViewController
        self.articleListController = articleListController
        super.init(nibName: nil, bundle: nil)
    }
    // swiftlint:enable function_parameter_count

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(DatabaseUseCase)!,
            themeRepository: injector.create(ThemeRepository)!,
            settingsRepository: injector.create(SettingsRepository)!,
            findFeedViewController: {injector.create(FindFeedViewController)!},
            localImportViewController: {injector.create(LocalImportViewController)!},
            feedViewController: {injector.create(FeedViewController)!},
            queryFeedViewController: {injector.create(QueryFeedViewController)!},
            settingsViewController: {injector.create(SettingsViewController)!},
            articleListController: {injector.create(ArticleListController)!}
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.addChildViewController(self.tableViewController)
        self.tableView.keyboardDismissMode = .OnDrag
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        self.tableView.addSubview(self.refreshView)
        self.updateRefreshViewSize(self.view.bounds.size)
        self.tableView.delegate = self

        self.navigationController?.navigationBar.addSubview(self.updateBar)
        if let _ = self.updateBar.superview {
            self.updateBar.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
            self.updateBar.autoSetDimension(.Height, toSize: 3)
        }

        self.view.addSubview(self.dropDownMenu)
        self.dropDownMenu.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        self.menuTopOffset = self.dropDownMenu.autoPinEdgeToSuperviewEdge(.Top)

        self.themeRepository.addSubscriber(self.notificationView)
        self.navigationController?.navigationBar.addSubview(self.notificationView)
        self.notificationView.autoPinEdgeToSuperviewMargin(.Trailing)
        self.notificationView.autoPinEdgeToSuperviewMargin(.Leading)
        self.notificationView.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.navigationController!.navigationBar)

        self.showLoadingView(NSLocalizedString("FeedsTableViewController_Loading_Feeds", comment: ""))

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self,
                                        action: #selector(FeedsTableViewController.didTapAddFeed))
        self.navigationItem.rightBarButtonItems = [addButton, self.tableViewController.editButtonItem()]

        let settingsTitle = NSLocalizedString("SettingsViewController_Title", comment: "")
        let settingsButton = UIBarButtonItem(title: settingsTitle,
            style: .Plain,
            target: self,
            action: #selector(FeedsTableViewController.presentSettings))
        self.navigationItem.leftBarButtonItem = settingsButton

        self.navigationItem.title = NSLocalizedString("FeedsTableViewController_Title", comment: "")

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(UIWebView.reload),
                                                         name: "UpdatedFeed", object: nil)

        if #available(iOS 9.0, *) {
            if self.traitCollection.forceTouchCapability == .Available {
                self.registerForPreviewingWithDelegate(self, sourceView: self.tableView)
            }
        }

        self.feedRepository.addSubscriber(self)
        self.themeRepository.addSubscriber(self)
        self.reload(self.searchBar.text)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    private func updateRefreshViewSize(size: CGSize) {
        let height: CGFloat = 100
        self.refreshView.frame = CGRect(x: 0, y: -height, width: size.width, height: height)
    }

    public override func viewWillTransitionToSize(size: CGSize,
        withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)

            self.updateRefreshViewSize(size)
    }

    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.refreshView.endRefreshing()
    }

    public override func canBecomeFirstResponder() -> Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        var commands = [
            UIKeyCommand(input: "f", modifierFlags: .Command, action: #selector(FeedsTableViewController.search)),
            UIKeyCommand(input: "i", modifierFlags: .Command,
                action: #selector(FeedsTableViewController.importFromWeb)),
            UIKeyCommand(input: "i", modifierFlags: [.Command, .Shift],
                action: #selector(FeedsTableViewController.importFromLocal)),
            UIKeyCommand(input: ",", modifierFlags: .Command,
                action: #selector(FeedsTableViewController.presentSettings)),
        ]
        if self.settingsRepository.queryFeedsEnabled {
            let command = UIKeyCommand(input: "i", modifierFlags: [.Command, .Alternate],
                                       action: #selector(FeedsTableViewController.createQueryFeed))
            commands.insert(command, atIndex: 3)
        }
        if #available(iOS 9.0, *) {
            var discoverabilityTitles = [
                NSLocalizedString("FeedsTableViewController_Command_Search", comment: ""),
                NSLocalizedString("FeedsTableViewController_Command_ImportWeb", comment: ""),
                NSLocalizedString("FeedsTableViewController_Command_ImportLocal", comment: ""),
                NSLocalizedString("FeedsTableViewController_Command_Settings", comment: ""),
            ]
            if self.settingsRepository.queryFeedsEnabled {
                let titleString = NSLocalizedString("FeedsTableViewController_Command_QueryFeed", comment: "")
                discoverabilityTitles.insert(titleString, atIndex: 3)
            }
            for (idx, cmd) in commands.enumerate() {
                cmd.discoverabilityTitle = discoverabilityTitles[idx]
            }
        }
        return commands
    }

    // MARK - Private/Internal

    internal func importFromWeb() { self.presentController(self.findFeedViewController()) }

    @objc private func importFromLocal() { self.presentController(self.localImportViewController()) }

    @objc private func createQueryFeed() { self.presentController(self.queryFeedViewController()) }

    @objc private func search() { self.searchBar.becomeFirstResponder() }

    @objc private func presentSettings() { self.presentController(self.settingsViewController()) }

    private func presentController(viewController: UIViewController) {
        let nc = UINavigationController(rootViewController: viewController)
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            let popover = UIPopoverController(contentViewController: nc)
            popover.popoverContentSize = CGSize(width: 600, height: 800)
            popover.presentPopoverFromBarButtonItem(self.navigationItem.rightBarButtonItem!,
                permittedArrowDirections: .Any, animated: true)
        } else {
            self.presentViewController(nc, animated: true, completion: nil)
        }
    }

    private func showLoadingView(message: String) {
        self.loadingView.configureWithMessage(message)
        self.view.addSubview(self.loadingView)
        self.loadingView.autoPinEdgesToSuperviewEdges()
    }

    private func reload(tag: String?, feeds: [Feed]? = nil) {
        let reloadWithFeeds: ([Feed]) -> (Void) = {feeds in
            let sortedFeeds = feeds.sort {(f1: Feed, f2: Feed) in
                let f1Unread = f1.unreadArticles.count
                let f2Unread = f2.unreadArticles.count
                if f1Unread != f2Unread {
                    return f1Unread > f2Unread
                }
                return f1.displayTitle.lowercaseString < f2.displayTitle.lowercaseString
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
                self.onboardingView.autoMatchDimension(.Width,
                    toDimension: .Width,
                    ofView: self.view,
                    withMultiplier: 0.75)
            }

            let oldFeeds = self.feeds
            self.feeds = sortedFeeds
            if oldFeeds != sortedFeeds {
                self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Right)
            } else {
                self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .None)
            }
        }

        if let feeds = feeds where (tag == nil || tag?.isEmpty == true) {
            reloadWithFeeds(feeds)
        }
        self.feedRepository.feedsMatchingTag(tag).then {
            if case let Result.Success(feeds) = $0 {
                reloadWithFeeds(feeds)
            }
        }
    }

    @objc private func didTapAddFeed() {
        guard self.navigationController?.visibleViewController == self else { return }

        if self.dropDownMenu.isOpen {
            self.dropDownMenu.closeAnimated(true)
        } else {
            var buttonTitles = [
                NSLocalizedString("FeedsTableViewController_Command_ImportWeb", comment: ""),
                NSLocalizedString("FeedsTableViewController_Command_ImportLocal", comment: ""),
            ]
            if self.settingsRepository.queryFeedsEnabled {
                buttonTitles.append(NSLocalizedString("FeedsTableViewController_Command_QueryFeed", comment: ""))
            }
            self.dropDownMenu.titles = buttonTitles
            let navBarHeight = self.navigationController!.navigationBar.frame.height
            let statusBarHeight = UIApplication.sharedApplication().statusBarFrame.height
            self.menuTopOffset.constant = navBarHeight + statusBarHeight
            self.dropDownMenu.openAnimated(true)
        }
    }

    private func feedAtIndexPath(indexPath: NSIndexPath) -> Feed! {
        return self.feeds[indexPath.row]
    }

    private func configuredArticleListWithFeeds(feed: Feed) -> ArticleListController {
        let articleListController = self.articleListController()
        articleListController.feed = feed
        return articleListController
    }

    private func showArticleList(articleListController: ArticleListController, animated: Bool) {
        self.navigationController?.pushViewController(articleListController, animated: animated)
    }

    internal func showFeed(feed: Feed, animated: Bool) -> ArticleListController {
        let al = self.configuredArticleListWithFeeds(feed)
        self.showArticleList(al, animated: animated)
        return al
    }
}

extension FeedsTableViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle

        self.tableView.backgroundColor = self.themeRepository.backgroundColor
        self.tableView.separatorColor = self.themeRepository.textColor
        self.tableView.indicatorStyle = self.themeRepository.scrollIndicatorStyle

        self.searchBar.barStyle = self.themeRepository.barStyle
        self.searchBar.backgroundColor = self.themeRepository.backgroundColor

        self.dropDownMenu.buttonBackgroundColor = self.themeRepository.tintColor
        self.dropDownMenu.backgroundColor = self.themeRepository.backgroundColor.colorWithAlphaComponent(0.5)

        self.refreshView.scenebackgroundColor = self.themeRepository.backgroundColor
        self.refreshView.textColor = self.themeRepository.textColor

        self.setNeedsStatusBarAppearanceUpdate()
    }
}

extension FeedsTableViewController: UISearchBarDelegate {
    public func searchBar(searchBar: UISearchBar, textDidChange text: String) {
        self.reload(text)
    }
}

extension FeedsTableViewController: DataSubscriber {
    public func markedArticles(articles: [Article], asRead read: Bool) {
        if self.markReadFuture == nil {
            self.reload(self.searchBar.text)
        }
    }

    public func deletedArticle(article: Article) {
        self.reload(self.searchBar.text)
    }

    public func deletedFeed(feed: Feed, feedsLeft: Int) {
        self.reload(self.searchBar.text)
    }

    public func willUpdateFeeds() {
        self.updateBar.hidden = false
        self.updateBar.progress = 0
        if !self.refreshView.isRefreshing {
            self.refreshView.beginRefreshing()
        }
    }

    public func didUpdateFeedsProgress(finished: Int, total: Int) {
        self.updateBar.setProgress(Float(finished) / Float(total), animated: true)
    }

    public func didUpdateFeeds(feeds: [Feed]) {
        self.updateBar.hidden = true
        if self.refreshView.isRefreshing {
            self.refreshView.endRefreshing()
        }
        self.refreshView.endRefreshing()
        self.reload(self.searchBar.text, feeds: feeds)
    }
}

extension FeedsTableViewController: MAKDropDownMenuDelegate {
    public func dropDownMenu(menu: MAKDropDownMenu!, itemDidSelect itemIndex: UInt) {
        if itemIndex == 0 {
            self.importFromWeb()
        } else if itemIndex == 1 {
            self.importFromLocal()
        } else if itemIndex == 2 {
            self.createQueryFeed()
        }
        menu.closeAnimated(true)
    }

    public func dropDownMenuDidTapOutsideOfItem(menu: MAKDropDownMenu!) {
        menu.closeAnimated(true)
    }
}

extension FeedsTableViewController: BreakOutToRefreshDelegate, UIScrollViewDelegate {
    public func refreshViewDidRefresh(refreshView: BreakOutToRefreshView) {
        self.feedRepository.updateFeeds({feeds, errors in
            if !errors.isEmpty {
                let alertTitle = NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Title", comment: "")

                let messageString = errors.filter({$0.userInfo["feedTitle"] != nil}).map({(error) -> (String) in
                    let title = error.userInfo["feedTitle"]!
                    let failureReason = error.localizedFailureReason ?? error.localizedDescription
                    return "\(title): \(failureReason)"
                }).joinWithSeparator("\n")

                let alertMessage = messageString
                self.notificationView.display(alertTitle, message: alertMessage)
            }
        })
    }

    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        self.refreshView.scrollViewWillBeginDragging(scrollView)
    }

    public func scrollViewWillEndDragging(scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            refreshView.scrollViewWillEndDragging(scrollView,
                withVelocity: velocity,
                targetContentOffset: targetContentOffset)
    }

    public func scrollViewDidScroll(scrollView: UIScrollView) {
        refreshView.scrollViewDidScroll(scrollView)
    }
}

extension FeedsTableViewController: UIViewControllerPreviewingDelegate {
    public func previewingContext(previewingContext: UIViewControllerPreviewing,
        viewControllerForLocation location: CGPoint) -> UIViewController? {
            if let indexPath = self.tableView.indexPathForRowAtPoint(location), feed = self.feedAtIndexPath(indexPath) {
                return configuredArticleListWithFeeds(feed)
            }
            return nil
    }

    public func previewingContext(previewingContext: UIViewControllerPreviewing,
        commitViewController viewControllerToCommit: UIViewController) {
            if let articleController = viewControllerToCommit as? ArticleListController {
                self.showArticleList(articleController, animated: true)
            }
    }
}

extension FeedsTableViewController: UITableViewDataSource {
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feeds.count
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let feed = feedAtIndexPath(indexPath)
        let cellTypeToUse = (feed.unreadArticles.isEmpty ? "unread": "read")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.

        if let cell = tableView.dequeueReusableCellWithIdentifier(cellTypeToUse,
            forIndexPath: indexPath) as? FeedTableCell {
                cell.feed = feed
                cell.themeRepository = self.themeRepository
                return cell
        }
        return UITableViewCell()
    }
}

extension FeedsTableViewController: UITableViewDelegate {
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        self.showFeed(self.feedAtIndexPath(indexPath), animated: true)
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle,
        forRowAtIndexPath indexPath: NSIndexPath) {}

    public func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let delete = UITableViewRowAction(style: .Default, title: deleteTitle) {(_, indexPath: NSIndexPath!) in
                let feed = self.feedAtIndexPath(indexPath)
                self.feeds = self.feeds.filter { $0 != feed }
                self.feedRepository.deleteFeed(feed)
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            }

            let readTitle = NSLocalizedString("FeedsTableViewController_Table_EditAction_MarkRead", comment: "")
            let markRead = UITableViewRowAction(style: .Normal, title: readTitle) {_, indexPath in
                let feed = self.feedAtIndexPath(indexPath)
                self.markReadFuture = self.feedRepository.markFeedAsRead(feed)
                self.markReadFuture!.then { _ in
                    self.reload(nil)
                    tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                    self.markReadFuture = nil
                }
            }

            let editTitle = NSLocalizedString("Generic_Edit", comment: "")
            let edit = UITableViewRowAction(style: .Normal, title: editTitle) {_, indexPath in
                let feed = self.feedAtIndexPath(indexPath)
                var viewController: UIViewController! = nil
                if feed.isQueryFeed {
                    let queryFeedViewController = self.queryFeedViewController()
                    queryFeedViewController.feed = feed
                    viewController = queryFeedViewController
                } else {
                    let feedViewController = self.feedViewController()
                    feedViewController.feed = feed
                    viewController = feedViewController
                }
                self.presentViewController(UINavigationController(rootViewController: viewController),
                    animated: true, completion: nil)
            }
            edit.backgroundColor = UIColor.blueColor()
            let feed = self.feedAtIndexPath(indexPath)
            if feed.isQueryFeed {
                return [delete, markRead, edit]
            } else {
                let shareTitle = NSLocalizedString("Generic_Share", comment: "")
                let share = UITableViewRowAction(style: .Normal, title: shareTitle) {_ in
                    guard let url = feed.url else { return }
                    let shareSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    self.presentViewController(shareSheet, animated: true, completion: nil)
                }
                share.backgroundColor = UIColor.darkGreenColor()
                return [delete, markRead, edit, share]
            }
    }
}

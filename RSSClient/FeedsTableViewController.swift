import UIKit
import BreakOutToRefresh
import MAKDropDownMenu
import rNewsKit

// swiftlint:disable file_length

public class FeedsTableViewController: UIViewController {
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
        dropDownMenu.buttonsInsets = UIEdgeInsetsMake(dropDownMenu.separatorHeight, 0, 0, 0)
        dropDownMenu.tintColor = UIColor.darkGreenColor()
        dropDownMenu.backgroundColor = UIColor(white: 0.75, alpha: 0.5)
        return dropDownMenu
    }()

    public lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: CGRectMake(0, 0, 320, 32))
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

    private lazy var dataWriter: DataWriter = {
        return self.injector!.create(DataWriter.self) as! DataWriter
    }()

    private lazy var dataRetriever: DataRetriever = {
        return self.injector!.create(DataRetriever.self) as! DataRetriever
    }()

    private lazy var themeRepository: ThemeRepository = {
        return self.injector!.create(ThemeRepository.self) as! ThemeRepository
    }()

    private lazy var settingsRepository: SettingsRepository = {
        return self.injector!.create(SettingsRepository.self) as! SettingsRepository
    }()

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

        self.showLoadingView(NSLocalizedString("FeedsTableViewController_Loading_Feeds", comment: ""))

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "didTapAddFeed")
        self.navigationItem.rightBarButtonItems = [addButton, self.tableViewController.editButtonItem()]

        let settingsTitle = NSLocalizedString("SettingsViewController_Title", comment: "")
        let settingsButton = UIBarButtonItem(title: settingsTitle,
            style: .Plain,
            target: self,
            action: "presentSettings")
        self.navigationItem.leftBarButtonItem = settingsButton

        self.navigationItem.title = NSLocalizedString("FeedsTableViewController_Title", comment: "")

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reload", name: "UpdatedFeed", object: nil)

        if #available(iOS 9.0, *) {
            if self.traitCollection.forceTouchCapability == .Available {
                self.registerForPreviewingWithDelegate(self, sourceView: self.tableView)
            }
        }

        self.dataWriter.addSubscriber(self)
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
            UIKeyCommand(input: "f", modifierFlags: .Command, action: "search"),
            UIKeyCommand(input: "i", modifierFlags: .Command, action: "importFromWeb"),
            UIKeyCommand(input: "i", modifierFlags: [.Command, .Shift], action: "importFromLocal"),
            UIKeyCommand(input: ",", modifierFlags: .Command, action: "presentSettings"),
        ]
        if self.settingsRepository.queryFeedsEnabled {
            let command = UIKeyCommand(input: "i", modifierFlags: [.Command, .Alternate], action: "createQueryFeed")
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

    internal func importFromWeb() { self.presentController(FindFeedViewController.self) }

    @objc private func importFromLocal() { self.presentController(LocalImportViewController.self) }

    @objc private func createQueryFeed() { self.presentController(QueryFeedViewController.self) }

    @objc private func search() { self.searchBar.becomeFirstResponder() }

    @objc private func presentSettings() { self.presentController(SettingsViewController.self) }

    private func presentController(controller: NSObject.Type) {
        if let viewController = self.injector?.create(controller) as? UIViewController {
            let nc = UINavigationController(rootViewController: viewController)
            if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
                let popover = UIPopoverController(contentViewController: nc)
                popover.popoverContentSize = CGSizeMake(600, 800)
                popover.presentPopoverFromBarButtonItem(self.navigationItem.rightBarButtonItem!,
                    permittedArrowDirections: .Any, animated: true)
            } else {
                self.presentViewController(nc, animated: true, completion: nil)
            }
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
                let f1Unread = f1.unreadArticles().count
                let f2Unread = f2.unreadArticles().count
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

            if sortedFeeds != self.feeds {
                self.feeds = sortedFeeds
                self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
            }
        }

        if let feeds = feeds where (tag == nil || tag?.isEmpty == true) {
            reloadWithFeeds(feeds)
        }
        self.dataRetriever.feedsMatchingTag(tag) {feeds in
            reloadWithFeeds(feeds)
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
            let navBarHeight = CGRectGetHeight(self.navigationController!.navigationBar.frame)
            let statusBarHeight = CGRectGetHeight(UIApplication.sharedApplication().statusBarFrame)
            self.menuTopOffset.constant = navBarHeight + statusBarHeight
            self.dropDownMenu.openAnimated(true)
        }
    }

    private func feedAtIndexPath(indexPath: NSIndexPath) -> Feed! {
        return feeds[indexPath.row]
    }

    private func configuredArticleListWithFeeds(feeds: [Feed]) -> ArticleListController {
        let al = ArticleListController(style: .Plain)
        al.dataWriter = self.dataWriter
        al.dataReader = self.dataRetriever
        al.themeRepository = self.themeRepository
        al.feeds = feeds
        return al
    }

    private func showArticleList(articleListController: ArticleListController, animated: Bool) {
        self.navigationController?.pushViewController(articleListController, animated: animated)
    }

    internal func showFeeds(feeds: [Feed], animated: Bool) -> ArticleListController {
        let al = self.configuredArticleListWithFeeds(feeds)
        self.showArticleList(al, animated: animated)
        return al
    }
}

extension FeedsTableViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
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
        self.reload(self.searchBar.text)
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
        self.dataWriter.updateFeeds({feeds, errors in
            if !errors.isEmpty {
                let alertTitle = NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Title", comment: "")

                let messageString = errors.filter({$0.userInfo["feedTitle"] != nil}).map({(error) -> (String) in
                    let title = error.userInfo["feedTitle"]!
                    let failureReason = error.localizedFailureReason ?? error.localizedDescription
                    return "\(title): \(failureReason)"
                }).joinWithSeparator("\n")

                let alertMessage = messageString
                let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .Alert)
                let actionTitle = NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Accept", comment: "")
                alert.addAction(UIAlertAction(title: actionTitle, style: .Default, handler: {_ in
                    self.dismissViewControllerAnimated(true, completion: nil)
                }))
                self.presentViewController(alert, animated: true, completion: nil)
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
                return configuredArticleListWithFeeds([feed])
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
        let cellTypeToUse = (feed.unreadArticles().isEmpty ? "unread": "read")
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

        self.showFeeds([self.feedAtIndexPath(indexPath)], animated: true)
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
                self.dataWriter.deleteFeed(feed)
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            }

            let readTitle = NSLocalizedString("FeedsTableViewController_Table_EditAction_MarkRead", comment: "")
            let markRead = UITableViewRowAction(style: .Normal, title: readTitle) {_, indexPath in
                let feed = self.feedAtIndexPath(indexPath)
                self.dataWriter.markFeedAsRead(feed)
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            }

            let editTitle = NSLocalizedString("Generic_Edit", comment: "")
            let edit = UITableViewRowAction(style: .Normal, title: editTitle) {_, indexPath in
                let feed = self.feedAtIndexPath(indexPath)
                var viewController: UIViewController! = nil
                if feed.isQueryFeed {
                    let vc = self.injector!.create(QueryFeedViewController.self) as! QueryFeedViewController
                    vc.feed = feed
                    viewController = vc
                } else {
                    let vc = self.injector!.create(FeedViewController.self) as! FeedViewController
                    vc.feed = feed
                    viewController = vc
                }
                self.presentViewController(UINavigationController(rootViewController: viewController),
                    animated: true, completion: nil)
            }
            edit.backgroundColor = UIColor.blueColor()
            return [delete, markRead, edit]
    }
}

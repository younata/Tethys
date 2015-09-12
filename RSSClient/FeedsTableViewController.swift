import UIKit
import BreakOutToRefresh
import MAKDropDownMenu
import rNewsKit

public class FeedsTableViewController: UIViewController {

    public lazy var tableView: UITableView = {
        let tableView = self.tableViewController.tableView
        tableView.tableHeaderView = self.searchBar
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self;

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
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        self.tableView.addSubview(self.refreshView)

        self.view.addSubview(self.updateBar)
        if let _ = self.updateBar.superview {
            self.updateBar.autoPinEdgeToSuperviewEdge(.Leading)
            self.updateBar.autoPinEdgeToSuperviewEdge(.Trailing)
            self.updateBar.autoPinEdgeToSuperviewEdge(.Top, withInset: 64)
            self.updateBar.autoSetDimension(.Height, toSize: 3)
        }

        self.view.addSubview(self.dropDownMenu)
        self.dropDownMenu.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        self.menuTopOffset = self.dropDownMenu.autoPinEdgeToSuperviewEdge(.Top)

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "didTapAddFeed")
        self.navigationItem.rightBarButtonItems = [addButton, self.tableViewController.editButtonItem()]

        let settingsTitle = NSLocalizedString("SettingsViewController_Title", comment: "")
        let settingsButton = UIBarButtonItem(title: settingsTitle, style: .Plain, target: self, action: "presentSettings")
        self.navigationItem.leftBarButtonItem = settingsButton

        self.navigationItem.title = NSLocalizedString("FeedsTableViewController_Title", comment: "")

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reload", name: "UpdatedFeed", object: nil)

        self.dataWriter.addSubscriber(self)
        self.themeRepository.addSubscriber(self)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.reload(self.searchBar.text)
    }

    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.refreshView.endRefreshing()
    }

    public override func canBecomeFirstResponder() -> Bool {
        return true
    }

    public override var keyCommands: [UIKeyCommand]? {
        var commands = [
            UIKeyCommand(input: "f", modifierFlags: .Command, action: "search"),
            UIKeyCommand(input: "i", modifierFlags: .Command, action: "importFromWeb"),
            UIKeyCommand(input: "i", modifierFlags: [.Command, .Shift], action: "importFromLocal"),
            UIKeyCommand(input: ",", modifierFlags: .Command, action: "presentSettings"),
        ]
        if self.settingsRepository.queryFeedsEnabled {
            commands.insert(UIKeyCommand(input: "i", modifierFlags: [.Command, .Alternate], action: "createQueryFeed"), atIndex: 3)
        }
        if #available(iOS 9.0, *) {
            var discoverabilityTitles = [
                NSLocalizedString("FeedsTableViewController_Command_Search", comment: ""),
                NSLocalizedString("FeedsTableViewController_Command_ImportWeb", comment: ""),
                NSLocalizedString("FeedsTableViewController_Command_ImportLocal", comment: ""),
                NSLocalizedString("FeedsTableViewController_Command_Settings", comment: ""),
            ]
            if self.settingsRepository.queryFeedsEnabled {
                discoverabilityTitles.insert(NSLocalizedString("FeedsTableViewController_Command_QueryFeed", comment: ""), atIndex: 3)
            }
            for (idx, cmd) in commands.enumerate() {
                cmd.discoverabilityTitle = discoverabilityTitles[idx]
            }
        }
        return commands
    }

    // MARK - Private/Internal

    internal func importFromWeb() {
        self.presentController(FindFeedViewController.self)
    }

    internal func importFromLocal() {
        self.presentController(LocalImportViewController.self)
    }

    internal func createQueryFeed() {
        self.presentController(QueryFeedViewController.self)
    }

    internal func search() {
        self.searchBar.becomeFirstResponder()
    }

    internal func presentSettings() {
        self.presentController(SettingsViewController.self)
    }

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

    private func reload(tag: String?) {
        self.dataRetriever.feedsMatchingTag(tag) {feeds in
            let sortedFeeds = feeds.sort {(f1: Feed, f2: Feed) in
                let f1Unread = f1.unreadArticles().count
                let f2Unread = f2.unreadArticles().count
                if f1Unread != f2Unread {
                    return f1Unread > f2Unread
                }
                return f1.title.lowercaseString < f2.title.lowercaseString
            }

            if self.refreshView.isRefreshing {
                self.refreshView.endRefreshing()
            }

            self.onboardingView.removeFromSuperview()
            if sortedFeeds.isEmpty {
                self.view.addSubview(self.onboardingView)
                self.onboardingView.autoCenterInSuperview()
                self.onboardingView.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view, withMultiplier: 0.75)
            }

            if sortedFeeds != self.feeds {
                self.feeds = sortedFeeds
                self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
            }
        }
    }

    internal func didTapAddFeed() {
        if (self.navigationController?.visibleViewController != self) {
            return
        }

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

    internal func showFeeds(feeds: [Feed], animated: Bool) -> ArticleListController {
        let al = ArticleListController(style: .Plain)
        al.dataWriter = self.dataWriter
        al.themeRepository = self.themeRepository
        al.feeds = feeds
        self.navigationController?.pushViewController(al, animated: animated)
        return al
    }
}

extension FeedsTableViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle

        self.tableView.backgroundColor = self.themeRepository.backgroundColor
        self.tableView.separatorColor = self.themeRepository.textColor

        self.searchBar.barStyle = self.themeRepository.barStyle
        self.searchBar.backgroundColor = self.themeRepository.backgroundColor

        self.dropDownMenu.buttonBackgroundColor = self.themeRepository.tintColor
        self.dropDownMenu.backgroundColor = self.themeRepository.backgroundColor.colorWithAlphaComponent(0.5)

        self.refreshView.scenebackgroundColor = self.themeRepository.backgroundColor

        self.setNeedsStatusBarAppearanceUpdate()
    }
}

extension FeedsTableViewController: UISearchBarDelegate {
    public func searchBar(searchBar: UISearchBar, textDidChange text: String) {
        self.reload(text)
    }
}

extension FeedsTableViewController: DataSubscriber {
    public func markedArticle(article: Article, asRead read: Bool) {}
    public func deletedArticle(article: Article) {}

    public func willUpdateFeeds() {
        self.updateBar.hidden = false
        self.updateBar.progress = 0
        if !self.refreshView.isRefreshing {
            self.refreshView.beginRefreshing()
        }
    }

    public func didUpdateFeedsProgress(finished: Int, total: Int) {
        self.updateBar.progress = Float(finished) / Float(total)
    }

    public func didUpdateFeeds(feeds: [Feed]) {
        self.updateBar.hidden = true
        if self.refreshView.isRefreshing {
            self.refreshView.endRefreshing()
        }
        self.refreshView.endRefreshing()
        self.reload(self.searchBar.text)
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
        dataWriter.updateFeeds({feeds, errors in
            if !errors.isEmpty {
                let alertTitle = NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Title", comment: "")
                let alertMessage = ""
                let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("FeedsTableViewController_UpdateFeeds_Error_Accept", comment: ""), style: .Default, handler: {_ in
                    self.dismissViewControllerAnimated(true, completion: nil)
                }))
                self.presentViewController(alert, animated: true, completion: nil)
            }
            self.reload(nil)
        })
    }

    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        self.searchBar.resignFirstResponder()
        refreshView.scrollViewWillBeginDragging(scrollView)
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

extension FeedsTableViewController: UITableViewDataSource {
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feeds.count
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let feed = feedAtIndexPath(indexPath)
        let cellTypeToUse = (feed.unreadArticles().isEmpty ? "unread" : "read")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.

        if let cell = tableView.dequeueReusableCellWithIdentifier(cellTypeToUse, forIndexPath: indexPath) as? FeedTableCell {
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

    public func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
        let delete = UITableViewRowAction(style: .Default, title: deleteTitle, handler: {(_, indexPath: NSIndexPath!) in
            let feed = self.feedAtIndexPath(indexPath)
            self.dataWriter.deleteFeed(feed)
            self.reload(nil)
        })

        let readTitle = NSLocalizedString("FeedsTableViewController_Table_EditAction_MarkRead", comment: "")
        let markRead = UITableViewRowAction(style: .Normal, title: readTitle, handler: {_, indexPath in
            let feed = self.feedAtIndexPath(indexPath)
            self.dataWriter.markFeedAsRead(feed)
            self.reload(nil)
        })

        let editTitle = NSLocalizedString("Generic_Edit", comment: "")
        let edit = UITableViewRowAction(style: .Normal, title: editTitle, handler: {_, indexPath in
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
        })
        edit.backgroundColor = UIColor.blueColor()
        return [delete, markRead, edit]
    }
}

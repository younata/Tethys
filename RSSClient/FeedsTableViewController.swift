import UIKit
import BreakOutToRefresh
import MAKDropDownMenu

public class FeedsTableViewController: UIViewController, UITableViewDelegate,
UITableViewDataSource, MAKDropDownMenuDelegate, UITextFieldDelegate,
UISearchBarDelegate, BreakOutToRefreshDelegate {

    public lazy var tableView: UITableView = {
        let tableView = self.tableViewController.tableView
        tableView.tableHeaderView = self.searchBar
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.setTranslatesAutoresizingMaskIntoConstraints(false)
        tableView.delegate = self
        tableView.dataSource = self;

        tableView.registerClass(FeedTableCell.self, forCellReuseIdentifier: "read")
        tableView.registerClass(FeedTableCell.self, forCellReuseIdentifier: "unread")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.

        return tableView
    }()

    lazy var dropDownMenu: MAKDropDownMenu = {
        let dropDownMenu = MAKDropDownMenu(forAutoLayout: ())

        dropDownMenu.delegate = self
        dropDownMenu.separatorHeight = 1.0 / UIScreen.mainScreen().scale
        dropDownMenu.buttonsInsets = UIEdgeInsetsMake(dropDownMenu.separatorHeight, 0, 0, 0)
        dropDownMenu.tintColor = UIColor.darkGreenColor()
        dropDownMenu.backgroundColor = UIColor(white: 0.75, alpha: 0.5)
        dropDownMenu.hidden = true

        return dropDownMenu
    }()

    lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: CGRectMake(0, 0, 320, 32))
        searchBar.autocorrectionType = .No
        searchBar.autocapitalizationType = .None
        searchBar.delegate = self
        searchBar.placeholder = NSLocalizedString("Filter by Tag", comment: "")
        return searchBar
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

    private var feeds: [Feed] = []

    private let tableViewController = UITableViewController(style: .Plain)

    private var menuTopOffset: NSLayoutConstraint!

    private lazy var dataManager: DataManager = { self.injector!.create(DataManager.self) as! DataManager }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.addChildViewController(tableViewController)
        self.view.addSubview(tableView)
        tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        tableView.addSubview(self.refreshView)

        self.view.addSubview(dropDownMenu)
        dropDownMenu.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        menuTopOffset = dropDownMenu.autoPinEdgeToSuperviewEdge(.Top)

        let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "didTapAddFeed")
        self.navigationItem.rightBarButtonItems = [addButton, tableViewController.editButtonItem()]
        self.navigationItem.title = NSLocalizedString("Feeds", comment: "")

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reload", name: "UpdatedFeed", object: nil)

        self.reload(nil)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    public override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation,
        duration: NSTimeInterval) {
            super.willRotateToInterfaceOrientation(toInterfaceOrientation, duration: duration)
            let landscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation)
            let statusBarHeight: CGFloat = (landscape ? 0 : 20)
            if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
                let navBarHeight: CGFloat = (landscape ? 32 : 44)
                menuTopOffset.constant = navBarHeight + statusBarHeight
            } else {
                menuTopOffset.constant = 44 + statusBarHeight
            }
            UIView.animateWithDuration(duration) {
                self.view.layoutIfNeeded()
            }
    }

    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.refreshView.endRefreshing()
    }

    // MARK: - BreakOutToRefreshDelegate

    public func refreshViewDidRefresh(refreshView: BreakOutToRefreshView) {
        dataManager.updateFeeds({error in
            if let err = error {
                let alertTitle = NSLocalizedString("Unable to update feeds", comment: "")
                let alertMessage = error?.localizedFailureReason
                let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: {_ in
                    self.dismissViewControllerAnimated(true, completion: nil)
                }))
                self.presentViewController(alert, animated: true, completion: nil)
            }
            self.reload(nil)
        })
    }

    // MARK: - UIScrollViewDelegate

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

    // MARK: MAKDropDownMenuDelegate

    public func dropDownMenu(menu: MAKDropDownMenu!, itemDidSelect itemIndex: UInt) {
        var klass: AnyClass! = nil
        if itemIndex == 0 {
            klass = FindFeedViewController.self
        } else if itemIndex == 1 {
            klass = LocalImportViewController.self
        } else if itemIndex == 2 {
            klass = QueryFeedViewController.self
        } else {
            menu.closeAnimated(true)
            return
        }
        if let viewController = self.injector?.create(klass) as? UIViewController {
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
        menu.closeAnimated(true)
    }

    public func dropDownMenuDidTapOutsideOfItem(menu: MAKDropDownMenu!) {
        menu.closeAnimated(true)
    }

    // MARK: UISearchBarDelegate

    public func searchBar(searchBar: UISearchBar, textDidChange text: String) {
        self.reload(text)
    }

    // MARK: - Table view data source

    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feeds.count
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let feed = feedAtIndexPath(indexPath)
        let strToUse = (feed.unreadArticles().isEmpty ? "unread" : "read")
        // Prevents a green triangle which'll (dis)appear depending on
        // whether new feed loaded into it has unread articles or not.

        if let cell = tableView.dequeueReusableCellWithIdentifier(strToUse, forIndexPath: indexPath) as? FeedTableCell {
            cell.dataManager = dataManager
            cell.feed = feed
            return cell
        }
        return UITableViewCell()
    }

    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        showFeeds([feedAtIndexPath(indexPath)], animated: true)
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }

    public func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle,
        forRowAtIndexPath indexPath: NSIndexPath) {}

    public func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        let deleteTitle = NSLocalizedString("Delete", comment: "")
        let delete = UITableViewRowAction(style: .Default, title: deleteTitle, handler: {(_, indexPath: NSIndexPath!) in
            let feed = self.feedAtIndexPath(indexPath)
//            self.dataManager.deleteFeed(feed)
            self.reload(nil)
        })

        let readTitle = NSLocalizedString("Mark\nRead", comment: "")
        let markRead = UITableViewRowAction(style: .Normal, title: readTitle, handler: {_, indexPath in
            let feed = self.feedAtIndexPath(indexPath)
//            self.dataManager.readArticles(feed.allArticles(self.dataManager))
            self.reload(nil)
        })

        let editTitle = NSLocalizedString("Edit", comment: "")
        let edit = UITableViewRowAction(style: .Normal, title: editTitle, handler: {_, indexPath in
            let feed = self.feedAtIndexPath(indexPath)
            var klass: AnyClass? = nil
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

    // MARK - Private

    private func reload(tag: String?) {
        let oldFeeds = feeds
        feeds = dataManager.feedsMatchingTag(tag).sorted {(f1: Feed, f2: Feed) in
            let f1Unread = f1.unreadArticles().count
            let f2Unread = f2.unreadArticles().count
            if f1Unread != f2Unread {
                return f1Unread > f2Unread
            }
            return f1.title.lowercaseString < f2.title.lowercaseString
        }

        if refreshView.isRefreshing {
            refreshView.endRefreshing()
        }

        self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: .Automatic)
    }

    private func didTapAddFeed() {
        if (self.navigationController!.visibleViewController != self) {
            return
        }

        dropDownMenu.titles = [NSLocalizedString("Add from Web", comment: ""),
            NSLocalizedString("Add from Local", comment: ""),
            NSLocalizedString("Create Query Feed", comment: "")]
        let navBarHeight = CGRectGetHeight(self.navigationController!.navigationBar.frame)
        let statusBarHeight = CGRectGetHeight(UIApplication.sharedApplication().statusBarFrame)
        menuTopOffset.constant = navBarHeight + statusBarHeight
        if dropDownMenu.isOpen {
            dropDownMenu.closeAnimated(true)
        } else {
            dropDownMenu.openAnimated(true)
        }
    }

    private func feedAtIndexPath(indexPath: NSIndexPath) -> Feed! {
        return feeds[indexPath.row]
    }

    private func showFeeds(feeds: [Feed], animated: Bool) -> ArticleListController {
        let al = ArticleListController(style: .Plain)
        al.dataManager = dataManager
        al.feeds = feeds
        self.navigationController?.pushViewController(al, animated: animated)
        return al
    }
}

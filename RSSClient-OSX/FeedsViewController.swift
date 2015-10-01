import Cocoa
import PureLayout_Mac
import rNewsKit
import Ra

public class FeedsViewController: NSViewController {
    var feeds : [Feed] = []

    public lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.setDelegate(self)
        tableView.setDataSource(self)
        tableView.headerView = nil
        tableView.addTableColumn(NSTableColumn())
        tableView.usesAlternatingRowBackgroundColors = true
        return tableView
    }()

    private lazy var tableHeightConstraint: NSLayoutConstraint? = nil

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView(forAutoLayout: ())
        scrollView.hasVerticalScroller = true
        scrollView.documentView = self.tableView
        return scrollView
    }()

    public private(set) var raInjector: Injector? = nil

    public var onFeedSelection : (Feed) -> Void = {(_) in }

    private var dataReader: DataRetriever? {
        return self.raInjector?.create(DataRetriever.self) as? DataRetriever
    }

    private var dataWriter: DataWriter? {
        return self.raInjector?.create(DataWriter.self) as? DataWriter
    }

    private var mainMenu: NSMenu? {
        return self.raInjector?.create(kMainMenu) as? NSMenu
    }

    public func configure(injector: Injector?) {
        self.raInjector = injector
        self.view = self.scrollView

        self.dataWriter?.addSubscriber(self)
        self.reload()

        if self.mainMenu?.itemWithTitle("Feeds") == nil {
            let menuItem = NSMenuItem(title: "Feeds", action: "unused", keyEquivalent: "")
            menuItem.target = self
            let submenu = NSMenu(title: "Feeds")

            let deleteAllFeeds = NSMenuItem(title: "Delete all feeds", action: Selector("didSelectDeleteAllFeeds"), keyEquivalent: "D")
            deleteAllFeeds.target = self
            let markAllFeedsAsRead = NSMenuItem(title: "Mark all feeds as read", action: Selector("didSelectMarkAllAsRead"), keyEquivalent: "R")
            markAllFeedsAsRead.target = self
            let reloadAllFeeds = NSMenuItem(title: "Refresh feeds", action: Selector("didSelectRefreshAllFeeds"), keyEquivalent: "r")
            reloadAllFeeds.target = self

            submenu.addItem(reloadAllFeeds)
            submenu.addItem(markAllFeedsAsRead)
            submenu.addItem(deleteAllFeeds)

            menuItem.submenu = submenu
            self.mainMenu?.insertItem(menuItem, atIndex: 3)
            self.mainMenu?.update()
        }
    }

    public override func viewWillLayout() {
        super.viewWillAppear()

        self.tableView.reloadData()
    }

    internal func unused() {}

    internal func didSelectDeleteAllFeeds() {
        for feed in self.feeds {
            self.dataWriter?.deleteFeed(feed)
        }
        self.reload()
    }

    internal func didSelectMarkAllAsRead() {
        for feed in self.feeds {
            self.dataWriter?.markFeedAsRead(feed)
        }
        self.reload()
    }

    internal func didSelectRefreshAllFeeds() {
        self.dataWriter?.updateFeeds {_ in }
    }

    internal func reload() {
        self.dataReader?.feeds {feeds in
            self.feeds = feeds
            self.tableView.reloadData()
        }
    }

    private func heightForFeed(feed: Feed, width: CGFloat) -> CGFloat {
        var height : CGFloat = 16.0
        let attributes = [NSFontAttributeName: NSFont.systemFontOfSize(12)]
        let title = NSAttributedString(string: feed.displayTitle, attributes: attributes)
        let summary = NSAttributedString(string: feed.displaySummary, attributes: attributes)

        let titleBounds = title.boundingRectWithSize(NSMakeSize(width, CGFloat.max), options: NSStringDrawingOptions.UsesFontLeading)
        let summaryBounds = summary.boundingRectWithSize(NSMakeSize(width, CGFloat.max), options: NSStringDrawingOptions.UsesFontLeading)

        let titleHeight = ceil(titleBounds.width / width) * ceil(titleBounds.height)
        let summaryHeight = ceil(summaryBounds.width / width) * ceil(summaryBounds.height)

        height += titleHeight
        height += summaryHeight

        return max(45, height)
    }
}

extension FeedsViewController: DataSubscriber {
    public func markedArticle(article: Article, asRead read: Bool) {}

    public func deletedArticle(article: Article) {}

    public func updatedFeeds(feeds: [Feed]) {
        self.reload()
    }
}

extension FeedsViewController: NSTableViewDataSource {
    public func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return self.feeds.count
    }
}

extension FeedsViewController: NSTableViewDelegate {
    public func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var feedView = tableView.makeViewWithIdentifier("feed", owner: self) as? FeedView
        if feedView == nil {
            feedView = FeedView(frame: NSZeroRect)
            feedView?.identifier = "feed"
        }
        feedView?.configure(self.feeds[row], delegate: self)
        return feedView
    }

    public func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return self.heightForFeed(self.feeds[row], width: tableView.bounds.width - 16)
    }
}

extension FeedsViewController: FeedViewDelegate {
    public func didClickFeed(feed: Feed) {
        self.onFeedSelection(feed)
    }

    private enum FeedsMenuOption: String {
        case MarkRead = "Mark as Read"
        case Delete = "Delete"

        static func allValues() -> [FeedsMenuOption] {
            return [.MarkRead, .Delete]
        }
    }

    public func menuOptionsForFeed(feed: Feed) -> [String] {
        return FeedsMenuOption.allValues().map { $0.rawValue }
    }

    public func didSelectMenuOption(menuOption: String, forFeed feed: Feed) {
        guard let feedsMenuOption = FeedsMenuOption(rawValue: menuOption) else {
            return
        }
        switch feedsMenuOption {
        case .MarkRead:
            self.dataWriter?.markFeedAsRead(feed)
        case .Delete:
            self.dataWriter?.deleteFeed(feed)
        }
        self.reload()
    }
}

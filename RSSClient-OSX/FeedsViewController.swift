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
        tableView.addTableColumn(NSTableColumn(identifier: "column"))
        tableView.usesAlternatingRowBackgroundColors = true
        return tableView
    }()

    private lazy var tableHeightConstraint: NSLayoutConstraint? = nil

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView(forAutoLayout: ())
        scrollView.hasVerticalScroller = true
        scrollView.documentView = self.tableView
        scrollView.verticalScroller?.target = self.tableView
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

    public func configure(injector: Injector?) {
        self.raInjector = injector
        self.view = self.scrollView

        self.dataWriter?.addSubscriber(self)
        self.reload()
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
        let title = NSAttributedString(string: feed.title, attributes: attributes)
        let summary = NSAttributedString(string: feed.summary, attributes: attributes)

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
        return feeds.count
    }
}

extension FeedsViewController: NSTableViewDelegate {
    public func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let feed = self.feeds[row]
        var feedView = tableView.makeViewWithIdentifier("feed", owner: self) as? FeedView
        if feedView == nil {
            feedView = FeedView(frame: NSZeroRect)
            feedView?.identifier = "feed"
        }
        feedView?.feed = feed
        return feedView
    }

    public func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return heightForFeed(feeds[row], width: tableView.bounds.width - 16)
    }

    public func tableView(tableView: NSTableView, shouldSelectRow rowIndex: Int) -> Bool {
        onFeedSelection(feeds[rowIndex])
        return false
    }
}

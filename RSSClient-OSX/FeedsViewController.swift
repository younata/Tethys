import Cocoa
import PureLayout_Mac
import rNewsKit
import Ra

public class FeedsViewController: NSViewController {
    var feeds : [Feed] = []

    public lazy var tableView: NSTableView = {
        let tableView = NSTableView(forAutoLayout: ())
        tableView.setDelegate(self)
        tableView.setDataSource(self)
        return tableView
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
        self.view = self.tableView

        self.dataWriter?.addSubscriber(self)
        self.reload()
    }

    func reload() {
        self.dataReader?.feeds {feeds in
            self.feeds = feeds
            self.tableView.reloadData()
        }
    }

    func heightForFeed(feed: Feed, width: CGFloat) -> CGFloat {
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

        return max(30, height)
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
    public func tableView(tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let feed = feeds[row]
        let feedView = FeedView(frame: NSMakeRect(0, 0, tableView.bounds.width, heightForFeed(feed, width: tableView.bounds.width - 16)))
        feedView.feed = feed
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

import Cocoa
import rNewsKit
import Ra

public class MainController: NSViewController {
    @IBOutlet public var window : NSWindow? = nil

    public lazy var feedsList: FeedsViewController = {
        let feedsList = FeedsViewController()
        feedsList.configure(self.raInjector)
        return feedsList
    }()

    public lazy var splitViewController : NSSplitViewController = {
        let controller = NSSplitViewController()
        controller.splitView.vertical = false
        self.addChildViewController(controller)
        return controller
    }()

    public override var acceptsFirstResponder : Bool {
        get {
            return true
        }
    }

    public private(set) var raInjector: Injector? = nil

    private lazy var opmlManager: OPMLManager? = {
        return self.raInjector?.create(OPMLManager.self) as? OPMLManager
    }()

    private lazy var dataWriter: DataWriter? = {
        return self.raInjector?.create(DataWriter.self) as? DataWriter
    }()

    public func configure(injector: Injector) {
        self.raInjector = injector
        self.feedsList.configure(injector)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let feedsSplitViewItem = NSSplitViewItem(viewController: self.feedsList)
        self.splitViewController.addSplitViewItem(feedsSplitViewItem)
        self.splitViewController.addChildViewController(self.feedsList)

        self.splitViewController.splitView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.splitViewController.view)
        self.splitViewController.view.autoPinEdgesToSuperviewEdgesWithInsets(NSEdgeInsetsZero)

        self.feedsList.view.autoPinEdgesToSuperviewEdgesWithInsets(NSEdgeInsetsZero)

        feedsList.reload()
        feedsList.onFeedSelection = showArticles

        window?.makeFirstResponder(self)
    }

    @IBAction public func openDocument(sender: AnyObject) {
        // open an opml file and import that...
        guard let injector = self.raInjector,
              let panel = injector.create(NSOpenPanel.self) as? NSOpenPanel else {
                return
        }
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["opml", "xml"]
        panel.beginSheetModalForWindow(self.window!) {result in
            guard result == NSFileHandlingPanelOKButton else {
                return
            }
            for url in panel.URLs as [NSURL] {
                self.opmlManager?.importOPML(url) {feeds in
                    if !feeds.isEmpty {
                        self.dataWriter?.updateFeeds {_ in }
                    }
                }
            }
        }
    }

    var articleTableView : NSTableView? = nil
    var articleScrollView : NSScrollView? = nil
    let articleList = ArticlesList()
    var articleListConstraint : NSLayoutConstraint? = nil

    func showArticles(feed: Feed) {
    }

    @IBAction func showFeeds(sender: NSObject) {
    }

    func showArticle(article: Article) {
        print("Show \(article.title)")
    }
}

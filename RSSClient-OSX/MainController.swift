import Cocoa
import rNewsKit
import Ra

public class MainController: NSViewController {
    @IBOutlet public var window : NSWindow? = nil

    public lazy var feedsList: FeedsViewController = {
        let feedsList = FeedsViewController()
        feedsList.configure()
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

    private var raInjector: Injector? = nil

    public func configure(injector: Injector) {
        self.raInjector = injector
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
        // open a feed or opml file and import that...
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["xml", "opml"]
        panel.beginSheetModalForWindow(self.window!) {result in
            if result == NSFileHandlingPanelOKButton {
                for url in panel.URLs as [NSURL] {
                    print("\(url)")
//                    self.dataManager?.importOPML(url)
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

import Cocoa
import rNewsKit

class MainController: NSViewController {
    @IBOutlet var window : NSWindow? = nil

    lazy var feedsList: FeedsViewController = {
        let feedsList = FeedsViewController()
        feedsList.configure()
        return feedsList
    }()

    lazy var splitViewController : NSSplitViewController = {
        let controller = NSSplitViewController()
        controller.splitView.vertical = false
        self.addChildViewController(controller)
        return controller
    }()

    override var acceptsFirstResponder : Bool {
        get {
            return true
        }
    }

    override func viewDidLoad() {
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

    @IBAction func openDocument(sender: AnyObject) {
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

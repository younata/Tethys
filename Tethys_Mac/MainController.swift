import Cocoa
import TethysKit

public final class MainController: NSViewController {
    @IBOutlet public var window: NSWindow?

    public lazy var feedsList: FeedsViewController = {
        let feedsList = FeedsViewController()
        feedsList.configure(self.raInjector)
        return feedsList
    }()

    public private(set) var articlesList: ArticleListViewController?

    public lazy var splitViewController: NSSplitViewController = {
        let controller = NSSplitViewController()
        controller.splitView.isVertical = false
        self.addChildViewController(controller)
        return controller
    }()

    public override var acceptsFirstResponder: Bool {
        return true
    }

    public private(set) var raInjector: Injector?

    private lazy var importUseCase: ImportUseCase? = {
        return self.raInjector?.create(kind: ImportUseCase.self)
    }()

    public func configure(_ injector: Injector) {
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
        self.splitViewController.view.autoPinEdgesToSuperviewEdges(with: NSEdgeInsetsZero)

        self.feedsList.view.autoPinEdgesToSuperviewEdges(with: NSEdgeInsetsZero)

        self.feedsList.reload()
        self.feedsList.onFeedSelection = showArticles

        self.window?.makeFirstResponder(self)
    }

    @IBAction public func openDocument(_ sender: AnyObject) {
        guard let injector = self.raInjector,
            let panel = injector.create(kind: NSOpenPanel.self) else {
                return
        }
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["opml", "xml"]
        panel.beginSheetModal(for: self.window!) {result in
            guard result == NSFileHandlingPanelOKButton else {
                return
            }
            for url in panel.urls as [URL] {
                _ = self.importUseCase?.scanForImportable(url).then { importable in
                    switch importable {
                    case let .feed(url, _):
                        _ = self.importUseCase?.importItem(url)
                    case let .opml(url, _):
                        _ = self.importUseCase?.importItem(url)
                    default:
                        break
                    }
                }
            }
        }
    }

    func showArticles(_ feed: Feed) {
        let articlesList = ArticleListViewController()
        articlesList.configure(articles: feed.articlesArray)
        let articlesSplitViewItem = NSSplitViewItem(viewController: articlesList)
        self.splitViewController.addSplitViewItem(articlesSplitViewItem)
        self.splitViewController.addChildViewController(articlesList)

        self.articlesList = articlesList
        self.splitViewController.splitView.adjustSubviews()
    }
}

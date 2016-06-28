import UIKit
import Ra
import rNewsKit

public func documentsDirectory() -> NSString {
    return (NSHomeDirectory() as NSString).stringByAppendingPathComponent("Documents")
}

public class LocalImportViewController: UIViewController, Injectable {
    private var opmls: [(NSURL, Int)] = []
    private var feeds: [(NSURL, Int)] = []
    private var contentsOfDirectory: [String] = []

    public let tableViewController = UITableViewController(style: .Plain)

    private var tableViewTopOffset: NSLayoutConstraint!

    private let themeRepository: ThemeRepository
    private let importUseCase: ImportUseCase
    private let analytics: Analytics

    public lazy var explanationLabel: ExplanationView = {
        let label = ExplanationView(forAutoLayout: ())
        label.themeRepository = self.themeRepository
        label.title = NSLocalizedString("LocalImportViewController_Title", comment: "")
        label.detail = NSLocalizedString("LocalImportViewController_Onboarding_Detail", comment: "")
        label.backgroundColor = UIColor.lightGrayColor()
        return label
    }()

    public init(themeRepository: ThemeRepository,
        importUseCase: ImportUseCase,
        analytics: Analytics) {
            self.themeRepository = themeRepository
            self.importUseCase = importUseCase
            self.analytics = analytics
            super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(ThemeRepository)!,
            importUseCase: injector.create(ImportUseCase)!,
            analytics: injector.create(Analytics)!
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.tableViewController.tableView)
        self.tableViewController.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        let inset = self.navigationController!.navigationBar.frame.height +
            UIApplication.sharedApplication().statusBarFrame.height
        self.tableViewTopOffset = self.tableViewController.tableView.autoPinEdgeToSuperviewEdge(.Top, withInset: inset)

        self.reloadItems()

        self.tableViewController.refreshControl = UIRefreshControl()
        self.tableViewController.refreshControl?.addTarget(self,
                                                           action: #selector(LocalImportViewController.reloadItems),
                                                           forControlEvents: .ValueChanged)

        self.navigationItem.title = NSLocalizedString("LocalImportViewController_Title", comment: "")
        let dismissTitle = NSLocalizedString("Generic_Dismiss", comment: "")
        let dismissButton = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self,
                                            action: #selector(LocalImportViewController.dismiss))
        self.navigationItem.leftBarButtonItem = dismissButton

        self.tableViewController.tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableViewController.tableView.delegate = self
        self.tableViewController.tableView.dataSource = self
        self.tableViewController.tableView.tableFooterView = UIView()

        self.themeRepository.addSubscriber(self)
        self.analytics.logEvent("DidViewLocalImport", data: nil)
    }

    internal func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    public func reloadItems() {
        let documentsUrl = NSURL(string: "file://\(NSHomeDirectory())/Documents/")!
        self.importUseCase.scanDirectoryForImportables(documentsUrl) { contents in
            self.opmls = contents.flatMap { item in
                switch item {
                case .OPML(let url, let feeds): return (url, feeds)
                default: return nil
                }
            }

            self.feeds = contents.flatMap { item in
                switch item {
                case .Feed(let url, let articles): return (url, articles)
                default: return nil
                }
            }

            self.feeds.sortInPlace { $0.0.absoluteString < $1.0.absoluteString }
            self.opmls.sortInPlace { $0.0.absoluteString < $1.0.absoluteString }
            self.showExplanationView()
            let sections = NSIndexSet(indexesInRange: NSRange(location: 0, length: 2))
            self.tableViewController.tableView.reloadSections(sections, withRowAnimation: .Automatic)

            self.tableViewController.refreshControl?.endRefreshing()
        }


    }

    // MARK: - Private

    private func showExplanationView() {
        self.explanationLabel.removeFromSuperview()
        let opmlIsEmptyOrHasOnlyRNews: Bool
        if self.opmls.count == 1, let opmlUrl = self.opmls.first?.0 {
            opmlIsEmptyOrHasOnlyRNews = opmlUrl.lastPathComponent == "rnews.opml"
        } else {
            opmlIsEmptyOrHasOnlyRNews = self.opmls.isEmpty
        }
        if self.feeds.isEmpty && opmlIsEmptyOrHasOnlyRNews {
            self.view.addSubview(self.explanationLabel)
            self.explanationLabel.autoCenterInSuperview()
            self.explanationLabel.autoMatchDimension(.Width,
                toDimension: .Width,
                ofView: self.view,
                withMultiplier: 0.75)
        }
    }

    private func disableInteractionWithMessage(message: String) -> ActivityIndicator {
        let activityIndicator = ActivityIndicator(forAutoLayout: ())
        activityIndicator.configureWithMessage(message)
        let color = activityIndicator.backgroundColor
        activityIndicator.backgroundColor = UIColor.clearColor()

        self.view.addSubview(activityIndicator)
        activityIndicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        UIView.animateWithDuration(0.3) {
            activityIndicator.backgroundColor = color
        }
        return activityIndicator
    }

    private func reenableInteractionAndDismiss(activityIndicator: ActivityIndicator) {
        activityIndicator.removeFromSuperview()
        self.dismiss()
    }
}

extension LocalImportViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.tableViewController.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableViewController.tableView.separatorColor = themeRepository.textColor
        self.tableViewController.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
    }
}

extension LocalImportViewController: UITableViewDataSource {
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return self.opmls.count
        case 1: return self.feeds.count
        default: return 0
        }
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath)

        cell.selectionStyle = .Gray

        if indexPath.section == 0 {
            let (url, feeds) = opmls[indexPath.row]
            cell.textLabel?.text = url.lastPathComponent
            let feedCount = NSLocalizedString("LocalImportViewController_Cell_FeedList_FeedCount", comment: "")
            cell.detailTextLabel?.text = NSString.localizedStringWithFormat(feedCount, feeds) as String
        } else if indexPath.section == 1 {
            let (url, articles) = feeds[indexPath.row]
            cell.textLabel?.text = url.lastPathComponent
            let articleCount = NSLocalizedString("LocalImportViewController_Cell_Feed_ArticleCount", comment: "")
            cell.detailTextLabel?.text = NSString.localizedStringWithFormat(articleCount, articles) as String
        }

        (cell as? TableViewCell)?.themeRepository = self.themeRepository

        return cell
    }

    public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            if self.opmls.isEmpty { return nil }
            return NSLocalizedString("LocalImportViewController_TableHeader_OPMLs", comment: "")
        case 1:
            if self.feeds.isEmpty { return nil }
            return NSLocalizedString("LocalImportViewController_TableHeader_Feeds", comment: "")
        default: return nil
        }
    }
}

extension LocalImportViewController: UITableViewDelegate {
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        let url: NSURL
        let activityIndicator: ActivityIndicator
        let analyticsImportType: String
        if indexPath.section == 0 {
            url = opmls[indexPath.row].0
            activityIndicator = disableInteractionWithMessage(NSLocalizedString("Importing feeds", comment: ""))
            analyticsImportType = "feed"
        } else if indexPath.section == 1 {
            url = feeds[indexPath.row].0
            activityIndicator = self.disableInteractionWithMessage(NSLocalizedString("Importing feed", comment: ""))
            analyticsImportType = "opml"
        } else { return }


        self.importUseCase.importItem(url) {
            self.analytics.logEvent("DidUseLocalImport", data: ["kind": analyticsImportType])
            self.reenableInteractionAndDismiss(activityIndicator)
        }
    }
}

import UIKit
import Ra
import Muon
import Lepton
import rNewsKit

public func documentsDirectory() -> NSString {
    return (NSHomeDirectory() as NSString).stringByAppendingPathComponent("Documents")
}

public class LocalImportViewController: UIViewController {
    private var opmls: [(String, [Lepton.Item])] = []
    private var feeds: [(String, Muon.Feed)] = []
    private var contentsOfDirectory: [String] = []

    public let tableViewController = UITableViewController(style: .Plain)

    private var tableViewTopOffset: NSLayoutConstraint!

    private lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter)
    }()

    private lazy var opmlService: OPMLService? = {
        return self.injector?.create(OPMLService)
    }()

    private lazy var mainQueue: NSOperationQueue? = {
        return self.injector?.create(kMainQueue) as? NSOperationQueue
    }()

    private lazy var backgroundQueue: NSOperationQueue? = {
        return self.injector?.create(kBackgroundQueue) as? NSOperationQueue
    }()

    private lazy var themeRepository: ThemeRepository? = {
        return self.injector?.create(ThemeRepository)
    }()

    private lazy var fileManager: NSFileManager? = {
        return self.injector?.create(NSFileManager)
    }()

    public lazy var explanationLabel: ExplanationView = {
        let label = ExplanationView(forAutoLayout: ())
        label.themeRepository = self.themeRepository
        label.title = NSLocalizedString("LocalImportViewController_Title", comment: "")
        label.detail = NSLocalizedString("LocalImportViewController_Onboarding_Detail", comment: "")
        label.backgroundColor = UIColor.lightGrayColor()
        return label
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.tableViewController.tableView)
        self.tableViewController.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        let inset = CGRectGetHeight(self.navigationController!.navigationBar.frame) +
            CGRectGetHeight(UIApplication.sharedApplication().statusBarFrame)
        self.tableViewTopOffset = self.tableViewController.tableView.autoPinEdgeToSuperviewEdge(.Top, withInset: inset)

        self.reloadItems()

        self.tableViewController.refreshControl = UIRefreshControl()
        self.tableViewController.refreshControl?.addTarget(self, action: "reloadItems", forControlEvents: .ValueChanged)

        self.navigationItem.title = NSLocalizedString("LocalImportViewController_Title", comment: "")
        let dismissTitle = NSLocalizedString("Generic_Dismiss", comment: "")
        let dismissButton = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem = dismissButton

        self.tableViewController.tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableViewController.tableView.delegate = self
        self.tableViewController.tableView.dataSource = self
        self.tableViewController.tableView.tableFooterView = UIView()

        self.themeRepository?.addSubscriber(self)
    }

    internal func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    public func reloadItems() {
        guard let fileManager = self.fileManager,
              let contents = try? fileManager.contentsOfDirectoryAtPath(documentsDirectory() as String) else {
            return
        }
        for path in contents {
            self.verifyIfFeedOrOPML(path)
        }

        if contents.isEmpty {
            self.showExplanationView()
        }

        self.tableViewController.refreshControl?.endRefreshing()
    }

    // MARK: - Private

    private func showExplanationView() {
        self.explanationLabel.removeFromSuperview()
        let opmlIsEmptyOrHasOnlyRNews: Bool
        if self.opmls.isEmpty {
            opmlIsEmptyOrHasOnlyRNews = true
        } else if let opmlPathString = self.opmls.first?.0 where self.opmls.count == 1 {
            opmlIsEmptyOrHasOnlyRNews = String(NSString(string: opmlPathString).lastPathComponent) == "rnews.opml"
        } else {
            opmlIsEmptyOrHasOnlyRNews = false
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

    private func reload() {
        self.feeds.sortInPlace { $0.0 < $1.0 }
        self.opmls.sortInPlace { $0.0 < $1.0 }
        self.showExplanationView()
        let sections = NSIndexSet(indexesInRange: NSMakeRange(0, 2))
        self.tableViewController.tableView.reloadSections(sections, withRowAnimation: .Automatic)
    }

    private func verifyIfFeedOrOPML(path: String) {
        if self.contentsOfDirectory.contains(path) {
            return
        }

        self.contentsOfDirectory.append(path)

        let location = documentsDirectory().stringByAppendingPathComponent(path)
        do {
            let text = try NSString(contentsOfFile: location, encoding: NSUTF8StringEncoding)
            let opmlParser = Lepton.Parser(text: text as String)
            let feedParser = FeedParser(string: text as String)
            feedParser.completion = {feed in
                self.feeds.append((path, feed))
                opmlParser.cancel()
                self.mainQueue?.addOperationWithBlock {
                    self.reload()
                }
            }
            opmlParser.success {items in
                let toAdd = (location, items)
                self.opmls.append(toAdd)
                feedParser.cancel()
                self.mainQueue?.addOperationWithBlock {
                    self.reload()
                }
            }
            self.backgroundQueue?.addOperations([opmlParser, feedParser], waitUntilFinished: false)
        } catch _ {
        }
    }

    private func disableInteractionWithMessage(message: String) -> ActivityIndicator {
        let activityIndicator = ActivityIndicator(forAutoLayout: ())
        activityIndicator.configureWithMessage(message)
        let color = activityIndicator.backgroundColor
        activityIndicator.backgroundColor = UIColor.clearColor()

        self.view.addSubview(activityIndicator)
        activityIndicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        UIView.animateWithDuration(0.3, animations: {
            activityIndicator.backgroundColor = color
        })
        return activityIndicator
    }

    private func reenableInteractionAndDismiss(activityIndicator: ActivityIndicator) {
        activityIndicator.removeFromSuperview()
        self.dismiss()
    }
}

extension LocalImportViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.tableViewController.tableView.backgroundColor = self.themeRepository?.backgroundColor
        self.tableViewController.tableView.separatorColor = self.themeRepository?.textColor

        if let themeRepository = self.themeRepository {
            self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
            self.tableViewController.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle
        }
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
            let (path, items) = opmls[indexPath.row]
            cell.textLabel?.text = NSString(string: path).lastPathComponent as String
            let feedCount = NSLocalizedString("LocalImportViewController_Cell_FeedList_FeedCount", comment: "")
            cell.detailTextLabel?.text = NSString.localizedStringWithFormat(feedCount, items.count) as String
        } else if indexPath.section == 1 {
            let (path, item) = feeds[indexPath.row]
            cell.textLabel?.text = path
            let articleCount = NSLocalizedString("LocalImportViewController_Cell_Feed_ArticleCount", comment: "")
            cell.detailTextLabel?.text = NSString.localizedStringWithFormat(articleCount, item.articles.count) as String
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
        if indexPath.section == 0 {
            let path = opmls[indexPath.row].0
            let activityIndicator = disableInteractionWithMessage(NSLocalizedString("Importing feeds", comment: ""))

            self.opmlService?.importOPML(NSURL(string: "file://" + path)!, completion: {(_) in
                self.dataWriter?.updateFeeds {_ in
                    self.reenableInteractionAndDismiss(activityIndicator)
                }
            })
        } else if indexPath.section == 1 {
            let feed = feeds[indexPath.row].1

            let activityIndicator = self.disableInteractionWithMessage(NSLocalizedString("Importing feed", comment: ""))

            self.dataWriter?.newFeed {newFeed in
                newFeed.url = feed.link
                self.dataWriter?.saveFeed(newFeed)
                self.dataWriter?.updateFeeds {_ in
                    self.reenableInteractionAndDismiss(activityIndicator)
                }
            }
        }
    }
}

import UIKit
import Ra
import Muon
import rNewsKit

public class LocalImportViewController: UIViewController {

    private class TableViewCell: UITableViewCell {
        required init(coder aDecoder: NSCoder) {
            fatalError("not supported")
        }

        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
            super.init(style: .Value1, reuseIdentifier: reuseIdentifier)
        }
    }

    private var opmls: [(String, [OPMLItem])] = []
    private var feeds: [(String, Muon.Feed)] = []
    private var contentsOfDirectory: [String] = []

    public let tableViewController = UITableViewController(style: .Plain)

    private var tableViewTopOffset: NSLayoutConstraint!

    private lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    private lazy var opmlManager: OPMLManager? = {
        return self.injector?.create(OPMLManager.self) as? OPMLManager
    }()

    private lazy var mainQueue: NSOperationQueue? = {
        return self.injector?.create(kMainQueue) as? NSOperationQueue
    }()

    private lazy var backgroundQueue: NSOperationQueue? = {
        return self.injector?.create(kBackgroundQueue) as? NSOperationQueue
    }()

    public lazy var explanationLabel: ExplanationView = {
        let label = ExplanationView(forAutoLayout: ())
        label.title = NSLocalizedString("Local Import", comment: "")
        label.detail = NSLocalizedString("To use Local Import, go into iTunes, select your phone, select apps, scroll down to installed apps, select rNews, and then click '+' to add an opml or rss feed to this app, refresh this page, and it'll automatically show up here so that you can import it.", comment: "")
        label.backgroundColor = UIColor.lightGrayColor()
        return label
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.tableViewController.tableView)
        self.tableViewController.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        let inset = CGRectGetHeight(self.navigationController!.navigationBar.frame) +
            CGRectGetHeight(UIApplication.sharedApplication().statusBarFrame)
        tableViewTopOffset = self.tableViewController.tableView.autoPinEdgeToSuperviewEdge(.Top, withInset: inset)

        self.reloadItems()

        self.tableViewController.refreshControl = UIRefreshControl()
        tableViewController.refreshControl?.addTarget(self, action: "reloadItems", forControlEvents: .ValueChanged)

        self.navigationItem.title = NSLocalizedString("Local Import", comment: "")
        let dismissTitle = NSLocalizedString("Dismiss", comment: "")
        let dismissButton = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem = dismissButton

        self.tableViewController.tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableViewController.tableView.delegate = self
        self.tableViewController.tableView.dataSource = self
        self.tableViewController.tableView.tableFooterView = UIView()
    }

    internal func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    public func reloadItems() {
        let fileManager = NSFileManager.defaultManager()
        do {
            let contents = try fileManager.contentsOfDirectoryAtPath(documentsDirectory() as String)
            for path in contents {
                verifyIfFeedOrOPML(path)
            }
        } catch _ {}

        self.tableViewController.refreshControl?.endRefreshing()
    }

    // MARK: - Private

    private func reload() {
        self.feeds.sortInPlace { $0.0 < $1.0 }
        self.opmls.sortInPlace { $0.0 < $1.0 }
        self.explanationLabel.removeFromSuperview()
        let opmlIsEmptyOrHasOnlyRNews: Bool// = (self.opmls.isEmpty || String(string: NSString(string: self.opmls.first?.0).lastPathComponent) == "rnews.opml")
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
            self.explanationLabel.autoMatchDimension(.Width, toDimension: .Width, ofView: self.view, withMultiplier: 0.75)
        }
        let sections = NSIndexSet(indexesInRange: NSMakeRange(0, 2))
        self.tableViewController.tableView.reloadSections(sections, withRowAnimation: .Automatic)
    }

    private func verifyIfFeedOrOPML(path: String) {
        if contentsOfDirectory.contains(path) {
            return;
        }

        contentsOfDirectory.append(path)

        let location = documentsDirectory().stringByAppendingPathComponent(path)
        do {
            let text = try NSString(contentsOfFile: location, encoding: NSUTF8StringEncoding)
            let opmlParser = OPMLParser(text: text as String)
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
            backgroundQueue?.addOperations([opmlParser, feedParser], waitUntilFinished: false)
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

        UIView.animateWithDuration(0.3, animations: {activityIndicator.backgroundColor = color})
        self.navigationItem.leftBarButtonItem?.enabled = false
        self.view.userInteractionEnabled = false
        return activityIndicator
    }

    private func reenableInteractionAndDismiss(activityIndicator: ActivityIndicator) {
        activityIndicator.removeFromSuperview()
        view.userInteractionEnabled = true
        navigationItem.leftBarButtonItem?.enabled = true
        dismiss()
    }
}

extension LocalImportViewController: UITableViewDataSource {
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (section) {
        case 0: return opmls.count
        case 1: return feeds.count
        default: return 0
        }
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath)

        if indexPath.section == 0 {
            let (path, items) = opmls[indexPath.row]
            cell.textLabel?.text = NSString(string: path).lastPathComponent as String
            cell.detailTextLabel?.text = "\(items.count) feeds"
        } else if indexPath.section == 1 {
            let (path, item) = feeds[indexPath.row]
            cell.textLabel?.text = path
            cell.detailTextLabel?.text = "\(item.articles.count) articles"
        }

        return cell
    }

    public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch (section) {
        case 0: return "Feed Lists"
        case 1: return "Individual Feeds"
        default: return ""
        }
    }
}

extension LocalImportViewController: UITableViewDelegate {
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        if indexPath.section == 0 {
            let path = opmls[indexPath.row].0
            let activityIndicator = disableInteractionWithMessage(NSLocalizedString("Importing feeds", comment: ""))

            self.opmlManager?.importOPML(NSURL(string: "file://" + path)!, completion: {(_) in
                self.reenableInteractionAndDismiss(activityIndicator)
            })
        } else if indexPath.section == 1 {
            let feed = feeds[indexPath.row].1

            let activityIndicator = disableInteractionWithMessage(NSLocalizedString("Importing feed", comment: ""))

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

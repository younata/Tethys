import UIKit
import Ra
import Muon
import rNewsKit

public class LocalImportViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private class TableViewCell: UITableViewCell {
        required init(coder aDecoder: NSCoder) {
            fatalError("not supported")
        }

        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
            super.init(style: .Value1, reuseIdentifier: reuseIdentifier)
        }
    }

    var opmls: [(String, [OPMLItem])] = []
    var feeds: [(String, Muon.Feed)] = []
    var contentsOfDirectory: [String] = []

    public let tableViewController = UITableViewController(style: .Plain)

    var tableViewTopOffset: NSLayoutConstraint!

    lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    lazy var opmlManager: OPMLManager? = {
        return self.injector?.create(OPMLManager.self) as? OPMLManager
    }()

    lazy var mainQueue: NSOperationQueue? = {
        return self.injector?.create(kMainQueue) as? NSOperationQueue
    }()

    lazy var backgroundQueue: NSOperationQueue? = {
        return self.injector?.create(kBackgroundQueue) as? NSOperationQueue
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
    }

    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    public func reloadItems() {
        let fileManager = NSFileManager.defaultManager()
        do {
            let contents = try fileManager.contentsOfDirectoryAtPath(documentsDirectory())
            for path in contents {
                verifyIfFeedOrOPML(path)
            }
        } catch _ {}

        self.tableViewController.refreshControl?.endRefreshing()
    }

    func reload() {
        self.feeds.sortInPlace { $0.0 < $1.0 }
        self.opmls.sortInPlace { $0.0 < $1.0 }
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

    // MARK: - Table view data source

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
            cell.textLabel?.text = path.lastPathComponent
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

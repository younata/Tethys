import UIKit
import Ra
import Muon

class LocalImportViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private class TableViewCell : UITableViewCell {
        required init(coder aDecoder: NSCoder) {
            fatalError("not supported")
        }

        override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
            super.init(style: .Value1, reuseIdentifier: reuseIdentifier)
        }
    }
    
    var opmls : [(String, [OPMLItem])] = []
    var feeds : [(String, Muon.Feed)] = []
    var contentsOfDirectory : [String] = []
    
    let tableViewController = UITableViewController(style: .Plain)
    
    var tableViewTopOffset: NSLayoutConstraint!

    lazy var dataManager : DataManager = { self.injector!.create(DataManager.self) as! DataManager }()

    lazy var backgroundQueue : NSOperationQueue = { self.injector!.create(kBackgroundQueue) as! NSOperationQueue }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.tableViewController.tableView)
        self.tableViewController.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        tableViewTopOffset = self.tableViewController.tableView.autoPinEdgeToSuperviewEdge(.Top, withInset: CGRectGetHeight(self.navigationController!.navigationBar.frame) + (UIApplication.sharedApplication().statusBarHidden ? 0 : 20))
        
        self.reloadItems()
        
        self.tableViewController.refreshControl = UIRefreshControl()
        tableViewController.refreshControl?.addTarget(self, action: "reloadItems", forControlEvents: .ValueChanged)
        
        self.navigationItem.title = NSLocalizedString("Local Import", comment: "")
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Dismiss", comment: ""), style: .Plain, target: self, action: "dismiss")
        
        self.tableViewController.tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableViewController.tableView.delegate = self
        self.tableViewController.tableView.dataSource = self
    }
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        super.willRotateToInterfaceOrientation(toInterfaceOrientation, duration: duration)
        let landscape = UIInterfaceOrientationIsLandscape(toInterfaceOrientation)
        let statusBarHeight : CGFloat = (landscape ? 0 : 20)
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            let navBarHeight : CGFloat = (landscape ? 32 : 44)
            tableViewTopOffset.constant = navBarHeight + statusBarHeight
        } else {
            tableViewTopOffset.constant = 44 + statusBarHeight
        }
        UIView.animateWithDuration(duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func reloadItems() {
        let documents : String = NSHomeDirectory().stringByAppendingPathComponent("Documents")
        if let fileManager = self.injector?.create(NSFileManager.self) as? NSFileManager,
            let contents = fileManager.contentsOfDirectoryAtPath(documents, error: nil) as? [String] {
                for path in contents {
                    verifyIfFeedOrOPML(path)
                }
        }
        
        self.tableViewController.refreshControl?.endRefreshing()
    }
    
    func reload() {
        self.feeds.sort { $0.0 < $1.0 }
        self.opmls.sort { $0.0 < $1.0 }
        self.tableViewController.tableView.reloadSections(NSIndexSet(indexesInRange: NSMakeRange(0, 2)), withRowAnimation: .Automatic)
    }
    
    private func verifyIfFeedOrOPML(path: String) {
        if contains(contentsOfDirectory, path) {
            return;
        }
        
        contentsOfDirectory.append(path)
        
        let location = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent(path)
        if let text = NSString(contentsOfFile: location, encoding: NSUTF8StringEncoding, error: nil) {
            let opmlParser = OPMLParser(text: text as String)
            let feedParser = FeedParser(string: text as String)
            feedParser.completion = {feed in
                self.feeds.append((path, feed))
                opmlParser.cancel()
                self.reload()
            }
            opmlParser.callback = {items in
                let toAdd = (path, items)
                self.opmls.append(toAdd)
                feedParser.cancel()
                self.reload()
            }
            backgroundQueue.addOperations([opmlParser, feedParser], waitUntilFinished: false)
        }
    }
    
    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (section) {
        case 0: return opmls.count
        case 1: return feeds.count
        default: return 0
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! UITableViewCell

        if indexPath.section == 0 {
            let (path, items) = opmls[indexPath.row]
            cell.textLabel?.text = path
            cell.detailTextLabel?.text = "\(items.count) feeds"
        } else if indexPath.section == 1 {
            let (path, item) = feeds[indexPath.row]
            cell.textLabel?.text = path
            cell.detailTextLabel?.text = "\(item.articles.count) articles"
        }

        return cell
    }

    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch (section) {
        case 0: return "Feed Lists"
        case 1: return "Individual Feeds"
        default: return ""
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)
        if indexPath.section == 0 {
            let path = opmls[indexPath.row].0
            let location = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent(path)

            let activityIndicator = disableInteractionWithMessage(NSLocalizedString("Importing feeds", comment: ""))

            dataManager.importOPML(NSURL(string: "file://" + location)!, progress: {_ in }, completion: {(_) in
                    self.reenableInteractionAndDismiss(activityIndicator)
            })
        } else if indexPath.section == 1 {
            let feed = feeds[indexPath.row].1

            let activityIndicator = disableInteractionWithMessage(NSLocalizedString("Importing feed", comment: ""))

            if let url = feed.link.absoluteString {
                self.dataManager.newFeed(url) {_ in
                    self.reenableInteractionAndDismiss(activityIndicator)
                }
            } else {
                self.reenableInteractionAndDismiss(activityIndicator)
            }
        }
    }

    private func disableInteractionWithMessage(message: String) -> ActivityIndicator {
        let activityIndicator = ActivityIndicator(forAutoLayout: ())
        activityIndicator.configureWithMessage(message)
        let color = activityIndicator.backgroundColor
        activityIndicator.backgroundColor = UIColor.clearColor()

        self.view.addSubview(activityIndicator)
        activityIndicator.autoCenterInSuperview()

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

import UIKit
import Muon
import Ra
import rNewsKit

public class FeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, Injectable {
    public var feed: rNewsKit.Feed? = nil {
        didSet {
            self.navigationItem.title = self.feed?.displayTitle ?? ""
            self.tableView.reloadData()
        }
    }

    private enum FeedSections: Int {
        case Title = 0
        case URL = 1
        case Summary = 2
        case Tags = 3

        var titleForSection: String {
            switch self {
            case .Title:
                return NSLocalizedString("FeedViewController_Table_Header_Title", comment: "")
            case .URL:
                return NSLocalizedString("FeedViewController_Table_Header_URL", comment: "")
            case .Summary:
                return NSLocalizedString("FeedViewController_Table_Header_Summary", comment: "")
            case .Tags:
                return NSLocalizedString("FeedViewController_Table_Header_Tags", comment: "")
            }
        }
    }

    public lazy var tableView: UITableView = {
        let tableView = UITableView(forAutoLayout: ())
        tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.registerClass(TextFieldCell.self, forCellReuseIdentifier: "text")
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()

    private let feedRepository: FeedRepository
    private let urlSession: NSURLSession
    private let operationQueue: NSOperationQueue
    private let themeRepository: ThemeRepository
    private let tagEditorViewController: Void -> TagEditorViewController

    private let intervalFormatter = NSDateIntervalFormatter()

    public init(feedRepository: FeedRepository,
                urlSession: NSURLSession,
                operationQueue: NSOperationQueue,
                themeRepository: ThemeRepository,
                tagEditorViewController: Void -> TagEditorViewController) {
        self.feedRepository = feedRepository
        self.urlSession = urlSession
        self.operationQueue = operationQueue
        self.themeRepository = themeRepository
        self.tagEditorViewController = tagEditorViewController

        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(FeedRepository)!,
            urlSession: injector.create(NSURLSession)!,
            operationQueue: injector.create(kBackgroundQueue) as! NSOperationQueue,
            themeRepository: injector.create(ThemeRepository)!,
            tagEditorViewController: {injector.create(TagEditorViewController)!}
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let dismissTitle = NSLocalizedString("Generic_Dismiss", comment: "")
        let dismissButton = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem = dismissButton

        let saveTitle = NSLocalizedString("Generic_Save", comment: "")
        let saveButton = UIBarButtonItem(title: saveTitle, style: .Plain, target: self, action: "save")
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.title = self.feed?.displayTitle ?? ""

        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.intervalFormatter.calendar = NSCalendar.currentCalendar()
        self.intervalFormatter.dateStyle = .MediumStyle
        self.intervalFormatter.timeStyle = .ShortStyle

        self.themeRepository.addSubscriber(self)
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    internal func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    internal func save() {
        if let theFeed = self.feed {
            self.feedRepository.saveFeed(theFeed)
        }
        self.dismiss()
    }

    private func showTagEditor(tagIndex: Int) -> TagEditorViewController {
        let tagEditorViewController = self.tagEditorViewController()
        tagEditorViewController.feed = self.feed
        if tagIndex < self.feed?.tags.count {
            tagEditorViewController.tagIndex = tagIndex
            tagEditorViewController.tagPicker.textField.text = self.feed?.tags[tagIndex]
        }
        self.navigationController?.pushViewController(tagEditorViewController, animated: true)
        return tagEditorViewController
    }

    // MARK: - Table view data source

    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        let numSection = 4
        return (feed == nil ? 0 : numSection)
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        if feed == nil {
            return 0
        }
        if let section = FeedSections(rawValue: sectionNum) where section == .Tags {
            return feed!.tags.count + 1
        }
        return 1
    }

    public func tableView(tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        if let section = FeedSections(rawValue: sectionNum) {
            return section.titleForSection
        }
        return nil
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let section = FeedSections(rawValue: indexPath.section) ?? .Title
        switch section {
        case .Title:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            cell.textLabel?.text = ""
            cell.themeRepository = self.themeRepository
            if let title = feed?.tags.filter({$0.hasPrefix("~")}).first {
                cell.textLabel?.text = title.substringFromIndex(title.startIndex.successor())
            } else if let title = feed?.displayTitle where !title.isEmpty {
                cell.textLabel?.text = title
            }
            return cell
        case .URL:
            return self.textFieldCell(indexPath)
        case .Summary:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            cell.textLabel?.text = ""
            cell.themeRepository = self.themeRepository
            if let summary = feed?.tags.filter({$0.hasPrefix("`")}).first {
                cell.textLabel?.text = summary.substringFromIndex(summary.startIndex.successor())
            } else if let summary = feed?.displaySummary where !summary.isEmpty {
                cell.textLabel?.text = summary
            } else {
                cell.textLabel?.text = NSLocalizedString("FeedViewController_Cell_Summary_Placeholder", comment: "")
                cell.textLabel?.textColor = UIColor.grayColor()
            }
            return cell
        case .Tags:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            cell.textLabel?.text = ""
            cell.themeRepository = self.themeRepository
            if let tags = feed?.tags {
                if indexPath.row == tags.count {
                    cell.textLabel?.text = NSLocalizedString("FeedViewController_Cell_AddTag", comment: "")
                    cell.textLabel?.textColor = UIColor.darkGreenColor()
                } else {
                    cell.textLabel?.text = tags[indexPath.row]
                }
            }
            return cell
        }
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        let isTagsSection = FeedSections(rawValue: indexPath.section) == .Tags
        let isEditableTag = indexPath.row != (tableView.numberOfRowsInSection(FeedSections.Tags.rawValue) - 1)

        return isTagsSection && isEditableTag
    }

    public func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            if feed == nil || FeedSections(rawValue: indexPath.section) != .Tags {
                return nil
            }
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let delete = UITableViewRowAction(style: .Default, title: deleteTitle, handler: {(_, indexPath) in
                if let feed = self.feed {
                    let tag = feed.tags[indexPath.row]
                    feed.removeTag(tag)
                    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                    if tag.hasPrefix("~") {
                        let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                    } else if tag.hasPrefix("`") {
                        let indexPath = NSIndexPath(forRow: 0, inSection: 1)
                        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                    }
                }
            })
            let editTitle = NSLocalizedString("Generic_Edit", comment: "")
            let edit = UITableViewRowAction(style: .Normal, title: editTitle, handler: {(_, indexPath) in
                self.showTagEditor(indexPath.row)
            })
            return [delete, edit]
    }

    public func tableView(tableView: UITableView,
        commitEditingStyle _: UITableViewCellEditingStyle,
        forRowAtIndexPath _: NSIndexPath) {}

    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        if FeedSections(rawValue: indexPath.section) == .Tags,
            let count = feed?.tags.count where indexPath.row == count {
                showTagEditor(indexPath.row)
        }
    }

    private func textFieldCell(indexPath: NSIndexPath) -> TextFieldCell {
        let tc = tableView.dequeueReusableCellWithIdentifier("text", forIndexPath: indexPath) as! TextFieldCell
        tc.onTextChange = {(_) in } // remove any previous onTextChange for setting stuff here.
        tc.themeRepository = self.themeRepository
        tc.textField.text = self.feed?.url?.absoluteString
        tc.showValidator = true
        tc.onTextChange = {(text) in
            if let txt = text, url = NSURL(string: txt) {
                self.urlSession.dataTaskWithURL(url) {data, response, error in
                    if let response = response as? NSHTTPURLResponse {
                        if let data = data,
                            let nstext = NSString(data: data, encoding: NSUTF8StringEncoding)
                            where response.statusCode == 200 {
                                let string = String(nstext)
                                let fp = Muon.FeedParser(string: string)
                                fp.failure {_ in tc.setValid(false) }
                                fp.success {_ in tc.setValid(true) }
                                self.operationQueue.addOperation(fp)
                        } else { tc.setValid(false) }
                    } else { tc.setValid(false) }
                    }.resume()
            }
            return
        }
        return tc
    }
}

extension FeedViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableView.separatorColor = themeRepository.textColor
        self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
    }
}

import UIKit
import rNewsKit

public class QueryFeedViewController: UITableViewController {

    public var feed: Feed? = nil {
        didSet {
            self.navigationItem.title = self.feed?.title ?? NSLocalizedString("New Query Feed", comment: "")
            if feed?.query == nil {
                feed?.query = "function(article) {\n    return !article.read;\n}"
            }
            self.tableView.reloadData()
        }
    }

    private enum FeedSections: Int {
        case Title = 0
        case Summary = 1
        case Query = 2
        case Tags = 3

        var titleForSection: String {
            switch self {
            case .Title:
                return NSLocalizedString("Title", comment: "")
            case .Summary:
                return NSLocalizedString("Summary", comment: "")
            case .Query:
                return NSLocalizedString("Query", comment: "")
            case .Tags:
                return NSLocalizedString("Tags", comment: "")
            }
        }
    }

    private lazy var dataWriter: DataWriter? = {
        return self.injector?.create(DataWriter.self) as? DataWriter
    }()

    private lazy var dataRetriever: DataRetriever? = {
        return self.injector?.create(DataRetriever.self) as? DataRetriever
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        let dismissTitle = NSLocalizedString("Dismiss", comment: "")
        let dismissButton = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem = dismissButton

        let saveTitle = NSLocalizedString("Save", comment: "")
        let saveButton = UIBarButtonItem(title: saveTitle, style: .Plain, target: self, action: "save")
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.title = self.feed?.displayTitle ?? NSLocalizedString("New Query Feed", comment: "")

        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "tags")
        tableView.registerClass(TextViewCell.self, forCellReuseIdentifier: "cell")

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 64
        tableView.tableFooterView = UIView()
    }

    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    func dismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    func save() {
        if let feed = self.feed {
            dataWriter?.saveFeed(feed)
        }
        dismiss()
    }

    func showTagEditor(tagIndex: Int) {
        let tagEditor = self.injector!.create(TagEditorViewController.self) as! TagEditorViewController
        tagEditor.feed = feed
        if tagIndex < feed?.tags.count {
            tagEditor.tagIndex = tagIndex
            tagEditor.tagPicker.textField.text = feed?.tags[tagIndex]
        }
        self.navigationController?.pushViewController(tagEditor, animated: true)
    }

    // MARK: - Table view data source

    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return feed == nil ? 3 : 4
    }

    public override func tableView(tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        if let theFeed = feed, let section = FeedSections(rawValue: sectionNum) where section == .Tags {
            return theFeed.tags.count + 1
        }
        return 1
    }

    public override func tableView(tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        if let section = FeedSections(rawValue: sectionNum) {
            return section.titleForSection
        }
        return nil
    }

    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if let section = FeedSections(rawValue: indexPath.section) {
            return cellForSection(section, tableView: tableView, indexPath: indexPath)
        }
        return UITableViewCell()
    }

    public override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if let section = FeedSections(rawValue: indexPath.section) {
            if section == .Tags {
                return indexPath.row < (feed?.tags.count ?? 1)
            } else if section == .Query {
                return true
            }
        }
        return false
    }

    public override func tableView(tableView: UITableView,
        commitEditingStyle _: UITableViewCellEditingStyle,
        forRowAtIndexPath _: NSIndexPath) {}

    public override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        if let section = FeedSections(rawValue: indexPath.section) {
            return editActionsForSection(section, indexPath: indexPath)
        }
        return nil
    }

    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        if FeedSections(rawValue: indexPath.section) == .Tags,
            let count = feed?.tags.count where indexPath.row == count {
                showTagEditor(indexPath.row)
        }
    }

    // MARK: - Private

    private func cellForSection(section: FeedSections, tableView: UITableView, indexPath: NSIndexPath) -> UITableViewCell {
        switch (section) {
        case .Title:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TextViewCell
            cell.textView.textColor = UIColor.blackColor()
            if let title = feed?.tags.filter({$0.hasPrefix("~")}).first {
                cell.textView.text = title.substringFromIndex(title.startIndex.successor())
            } else if let title = feed?.displayTitle where !title.isEmpty {
                cell.textView.text = title
            } else {
                cell.textView.text = NSLocalizedString("No title available", comment: "")
                cell.textView.textColor = UIColor.grayColor()
            }
            cell.onTextChange = {
                if let feed = self.feed {
                    feed.title = $0 ?? ""
                }
                self.navigationItem.rightBarButtonItem?.enabled = self.feed?.title != nil && self.feed?.query != nil
            }
            return cell
        case .Summary:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TextViewCell
            cell.textView.textColor = UIColor.blackColor()
            if let summary = feed?.tags.filter({$0.hasPrefix("`")}).first {
                cell.textView.text = summary.substringFromIndex(summary.startIndex.successor())
            } else if let summary = feed?.displaySummary where !summary.isEmpty {
                cell.textView.text = summary
            } else {
                cell.textView.text = NSLocalizedString("No summary available", comment: "")
                cell.textView.textColor = UIColor.grayColor()
            }
            cell.onTextChange = {
                if let feed = self.feed {
                    feed.summary = $0 ?? ""
                }
            }
            return cell
        case .Query:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TextViewCell
            cell.textView.textColor = UIColor.blackColor()
            if let query = feed?.query {
                cell.textView.text = query
            } else {
                cell.textView.text = "function(article) {\n    return !article.read;\n}"
            }
            cell.onTextChange = {_ in }
            cell.applyStyling()
            cell.onTextChange = {
                if let feed = self.feed {
                    feed.query = $0 ?? ""
                }
                self.navigationItem.rightBarButtonItem?.enabled = self.feed?.title != nil && self.feed?.query != nil
            }
            return cell
        case .Tags:
            let cell = tableView.dequeueReusableCellWithIdentifier("tags", forIndexPath: indexPath) as UITableViewCell
            if let tags = feed?.tags {
                if indexPath.row == tags.count {
                    cell.textLabel?.text = NSLocalizedString("Add Tag", comment: "")
                    cell.textLabel?.textColor = UIColor.darkGreenColor()
                } else {
                    cell.textLabel?.text = tags[indexPath.row]
                    cell.textLabel?.textColor = UIColor.blackColor()
                }
            }
            return cell
        }
    }

    private func editActionsForSection(section: FeedSections, indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        if feed == nil {
            return nil
        }
        switch section {
        case .Query:
            let previewTitle = NSLocalizedString("Preview", comment: "")
            let preview = UITableViewRowAction(style: .Normal, title: previewTitle, handler: {(_, _) in
                let articleList = ArticleListController(style: .Plain)
                articleList.previewMode = true
                self.dataRetriever?.articlesMatchingQuery(self.feed?.query ?? "") {articles in
                    articleList.articles = articles
                }
                self.navigationController?.pushViewController(articleList, animated: true)
            })
            return [preview]
        case .Tags:
            if indexPath.row == feed?.tags.count {
                return nil
            }
            let deleteTitle = NSLocalizedString("Delete", comment: "")
            let delete = UITableViewRowAction(style: .Default, title: deleteTitle, handler: {(_, indexPath) in
                if let feed = self.feed {
                    let tag = feed.tags[indexPath.row]
                    feed.removeTag(tag)
                    self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                    if tag.hasPrefix("~") {
                        let ip = NSIndexPath(forRow: 0, inSection: 0)
                        self.tableView.reloadRowsAtIndexPaths([ip], withRowAnimation: .None)
                    } else if tag.hasPrefix("`") {
                        let ip = NSIndexPath(forRow: 0, inSection: 1)
                        self.tableView.reloadRowsAtIndexPaths([ip], withRowAnimation: .None)
                    }
                }
            })
            let editTitle = NSLocalizedString("Edit", comment: "")
            let edit = UITableViewRowAction(style: .Normal, title: editTitle, handler: {(_, indexPath) in
                self.showTagEditor(indexPath.row)
            })
            return [delete, edit]
        default:
            return nil
        }
    }
}

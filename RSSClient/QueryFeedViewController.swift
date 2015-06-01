import UIKit

public class QueryFeedViewController: UITableViewController {

    var feed: Feed? = nil {
        didSet {
            self.navigationItem.title = self.feed?.title ?? NSLocalizedString("New Query Feed", comment: "")
            self.tableView.reloadData()
            if feed?.query == nil {
                feed?.query = "function(article) {\n    return !article.read;\n}"
            }
        }
    }

    lazy var dataManager: DataManager = {
        return self.injector!.create(DataManager.self) as! DataManager
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        let dismissTitle = NSLocalizedString("Done", comment: "")
        let dismissButton = UIBarButtonItem(title: dismissTitle, style: .Plain, target: self, action: "dismiss")
        self.navigationItem.leftBarButtonItem = dismissButton

        let saveTitle = NSLocalizedString("Save", comment: "")
        let saveButton = UIBarButtonItem(title: saveTitle, style: .Plain, target: self, action: "save")
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.title = self.feed?.title ?? NSLocalizedString("New Query Feed", comment: "")

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
        if let feed = self.feed {
            if feed.title.isEmpty && feed.query == nil {
//                dataManager.deleteFeed(feed)
            }
        }
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    func save() {
        if let feed = self.feed {
            if feed.title.isEmpty && feed.query == nil {
//                dataManager.deleteFeed(feed)
            }
//            feed.managedObjectContext?.save(nil)
        }
//        dataManager.writeOPML()
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

    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section != 3 {
            return 1
        }
        return (feed?.tags.count ?? 0) + 1
    }

    public override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("Title", comment: "")
        case 1:
            return NSLocalizedString("Summary", comment: "")
        case 2:
            return NSLocalizedString("Query", comment: "")
        case 3:
            return NSLocalizedString("Tags", comment: "")
        default:
            return nil
        }
    }

    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 3 {
            let cell = tableView.dequeueReusableCellWithIdentifier("tags", forIndexPath: indexPath) as! UITableViewCell
            if let tags = feed?.tags {
                if indexPath.row == tags.count {
                    cell.textLabel?.text = NSLocalizedString("Add Tag", comment: "")
                    cell.textLabel?.textColor = UIColor.darkGreenColor()
                } else {
                    cell.textLabel?.text = tags[indexPath.row]
                }
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TextViewCell
            cell.textView.textColor = UIColor.blackColor()
            switch (indexPath.section) {
            case 0:
                if let title = (feed?.title == "" ? nil : feed?.title) {
                    cell.textView.text = title
                } else {
                    cell.textView.text = NSLocalizedString("No title available", comment: "")
                    cell.textView.textColor = UIColor.grayColor()
                }
                cell.onTextChange = {
                    if var feed = self.feed {
                        feed.title = $0 ?? ""
                    }
                    self.navigationItem.rightBarButtonItem?.enabled = self.feed?.title != nil && self.feed?.query != nil
                }
            case 1:
                if let summary = (feed?.summary == "" ? nil : feed?.summary)  {
                    cell.textView.text = summary
                } else {
                    cell.textView.text = NSLocalizedString("No summary available", comment: "")
                    cell.textView.textColor = UIColor.grayColor()
                }
                cell.onTextChange = {
                    if var feed = self.feed {
                        feed.summary = $0 ?? ""
                    }
                }
            case 2:
                if let query = feed?.query {
                    cell.textView.text = query
                } else {
                    cell.textView.text = "function(article) {\n    return !article.read;\n}"
                }
                cell.onTextChange = {
                    if var feed = self.feed {
                        feed.query = $0 ?? ""
                    }
                    self.navigationItem.rightBarButtonItem?.enabled = self.feed?.title != nil && self.feed?.query != nil
                }
            default:
                break
            }
            return cell
        }
    }

    public override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if indexPath.section == 3 {
            return indexPath.row < (feed?.tags.count ?? 1)
        } else if indexPath.section == 2 {
            return true
        }
        return false
    }

    public override func tableView(tableView: UITableView,
        commitEditingStyle _: UITableViewCellEditingStyle,
        forRowAtIndexPath _: NSIndexPath) {}

    public override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        if feed == nil && indexPath.section < 2 && feed?.tags.count == indexPath.row {
            return nil
        }
        if indexPath.section == 2 {
            let previewTitle = NSLocalizedString("Preview", comment: "")
            let preview = UITableViewRowAction(style: .Normal, title: previewTitle, handler: {(_, _) in
                let articleList = ArticleListController(style: .Plain)
                articleList.previewMode = true
                articleList.articles = self.dataManager.articlesMatchingQuery(self.feed?.query ?? "")
                self.navigationController?.pushViewController(articleList, animated: true)
            })
            return [preview]
        } else if indexPath.section == 3 {
            let deleteTitle = NSLocalizedString("Delete", comment: "")
            let delete = UITableViewRowAction(style: .Default, title: deleteTitle, handler: {(_, indexPath) in
                if var feed = self.feed {
                    let tag = feed.tags[indexPath.row]
                    feed.removeTag(tag)
                    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                    if tag.hasPrefix("~") {
                        let ip = NSIndexPath(forRow: 0, inSection: 0)
                        tableView.reloadRowsAtIndexPaths([ip], withRowAnimation: .None)
                    } else if tag.hasPrefix("`") {
                        let ip = NSIndexPath(forRow: 0, inSection: 1)
                        tableView.reloadRowsAtIndexPaths([ip], withRowAnimation: .None)
                    }
                }
            })
            let editTitle = NSLocalizedString("Edit", comment: "")
            let edit = UITableViewRowAction(style: .Normal, title: editTitle, handler: {(_, indexPath) in
                self.showTagEditor(indexPath.row)
            })
            return [delete, edit]
        }
        return nil
    }

    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        if indexPath.section == 3,
            let count = feed?.tags.count where indexPath.row == count {
                showTagEditor(indexPath.row)
        }
    }
}

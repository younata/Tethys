import UIKit
import Ra
import rNewsKit

public class QueryFeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, Injectable {
    public var feed: Feed? = nil {
        didSet {
            let newTitle = NSLocalizedString("QueryFeedViewController_Title_New", comment: "")
            self.navigationItem.title = self.feed?.title ?? newTitle
            if feed?.query == nil {
                feed?.query = "function(article) {\n    return !article.read;\n}"
            }
            self.feedTitle = feed?.displayTitle ?? ""
            self.feedSummary = feed?.displaySummary ?? ""
            self.feedQuery = feed?.query ?? ""
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
                return NSLocalizedString("FeedViewController_Table_Header_Title", comment: "")
            case .Summary:
                return NSLocalizedString("FeedViewController_Table_Header_Summary", comment: "")
            case .Query:
                return NSLocalizedString("QueryFeedViewController_Table_Header_Query", comment: "")
            case .Tags:
                return NSLocalizedString("FeedViewController_Table_Header_Tags", comment: "")
            }
        }
    }

    private let feedRepository: FeedRepository
    private let themeRepository: ThemeRepository
    private let tagEditorViewController: TagEditorViewController
    private let articleListController: ArticleListController

    public lazy var tableView: UITableView = {
        let tableView = UITableView(forAutoLayout: ())

        tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "tags")
        tableView.registerClass(TextFieldCell.self, forCellReuseIdentifier: "cell")
        tableView.registerClass(TextViewCell.self, forCellReuseIdentifier: "query")

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 64
        tableView.tableFooterView = UIView()

        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()

    private var feedTitle = ""
    private var feedSummary = ""
    private var feedQuery = "function(article) {\n    return !article.read;\n}"

    public init(feedRepository: FeedRepository,
                themeRepository: ThemeRepository,
                tagEditorViewController: TagEditorViewController,
                articleListController: ArticleListController) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.tagEditorViewController = tagEditorViewController
        self.articleListController = articleListController

        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(
            feedRepository: injector.create(FeedRepository)!,
            themeRepository: injector.create(ThemeRepository)!,
            tagEditorViewController: injector.create(TagEditorViewController)!,
            articleListController: injector.create(ArticleListController)!
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
        saveButton.enabled = self.feed != nil
        self.navigationItem.rightBarButtonItem = saveButton
        self.navigationItem.title = self.feed?.displayTitle ?? NSLocalizedString("New Query Feed", comment: "")

        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

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
        let saveFeed: (Feed) -> (Void) = {feed in
            if !self.feedTitle.isEmpty {
                feed.title = self.feedTitle
            }
            if !self.feedSummary.isEmpty {
                feed.summary = self.feedSummary
            }
            if !self.feedQuery.isEmpty {
                feed.query = self.feedQuery
            }
            self.feedRepository.saveFeed(feed)
            self.dismiss()
        }
        if let feed = self.feed {
            saveFeed(feed)
        } else {
            self.feedRepository.newFeed {feed in
                saveFeed(feed)
            }
        }
    }

    private func showTagEditor(tagIndex: Int) {
        self.tagEditorViewController.feed = feed
        if tagIndex < feed?.tags.count {
            self.tagEditorViewController.tagIndex = tagIndex
            self.tagEditorViewController.tagPicker.textField.text = feed?.tags[tagIndex]
        }
        self.navigationController?.pushViewController(self.tagEditorViewController, animated: true)
    }

    // MARK: - Table view data source

    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return feed == nil ? 3 : 4
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        if let theFeed = feed, let section = FeedSections(rawValue: sectionNum) where section == .Tags {
            return theFeed.tags.count + 1
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
        if let section = FeedSections(rawValue: indexPath.section) {
            return cellForSection(section, indexPath: indexPath)
        }
        return UITableViewCell()
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if let section = FeedSections(rawValue: indexPath.section) {
            if section == .Tags {
                return indexPath.row < (feed?.tags.count ?? 1)
            } else if section == .Query {
                return true
            }
        }
        return false
    }

    public func tableView(tableView: UITableView,
        commitEditingStyle _: UITableViewCellEditingStyle,
        forRowAtIndexPath _: NSIndexPath) {}

    public func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            if let section = FeedSections(rawValue: indexPath.section) {
                return editActionsForSection(section, indexPath: indexPath)
            }
            return nil
    }

    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: false)

        if FeedSections(rawValue: indexPath.section) == .Tags,
            let count = feed?.tags.count where indexPath.row == count {
                showTagEditor(indexPath.row)
        }
    }

    private func cellForSection(section: FeedSections, indexPath: NSIndexPath) -> UITableViewCell {
        switch section {
        case .Title:
            let cell = self.tableView.dequeueReusableCellWithIdentifier("cell",
                forIndexPath: indexPath) as! TextFieldCell
            cell.textField.text = self.feedTitle
            let placeholder = NSLocalizedString("QueryFeedViewController_Cell_Title_Placeholder", comment: "")
            cell.textField.placeholder = placeholder
            cell.themeRepository = self.themeRepository
            cell.onTextChange = {
                self.feedTitle = $0 ?? ""
                self.navigationItem.rightBarButtonItem?.enabled = !self.feedTitle.isEmpty && !self.feedQuery.isEmpty
            }
            return cell
        case .Summary:
            let cell = self.tableView.dequeueReusableCellWithIdentifier("cell",
                forIndexPath: indexPath) as! TextFieldCell
            cell.textField.text = self.feedSummary
            cell.themeRepository = self.themeRepository
            let placeholder = NSLocalizedString("QueryFeedViewController_Cell_Summary_Placeholder", comment: "")
            cell.textField.placeholder = placeholder
            cell.onTextChange = {
                self.feedSummary = $0 ?? ""
            }
            return cell
        case .Query:
            let cell = self.tableView.dequeueReusableCellWithIdentifier("query",
                forIndexPath: indexPath) as! TextViewCell
            cell.textView.textColor = UIColor.blackColor()
            cell.textView.text = self.feedQuery
            cell.onTextChange = {_ in }
            cell.themeRepository = self.themeRepository
            cell.applyStyling()
            cell.onTextChange = {
                self.feedQuery = $0 ?? ""
                self.navigationItem.rightBarButtonItem?.enabled = !self.feedTitle.isEmpty && !self.feedQuery.isEmpty
            }
            return cell
        case .Tags:
            let cell = self.tableView.dequeueReusableCellWithIdentifier("tags",
                forIndexPath: indexPath) as! TableViewCell
            cell.themeRepository = self.themeRepository
            if let tags = self.feed?.tags {
                if indexPath.row == tags.count {
                    cell.textLabel?.text = NSLocalizedString("FeedViewController_Cell_AddTag", comment: "")
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
        switch section {
        case .Query:
            let previewTitle = NSLocalizedString("QueryFeedViewController_Cell_Action_Preview", comment: "")
            let preview = UITableViewRowAction(style: .Normal, title: previewTitle, handler: {(_, _) in
                self.articleListController.previewMode = true
                self.feedRepository.articlesMatchingQuery(self.feedQuery) {articles in
                    self.articleListController.articles = DataStoreBackedArray(articles)
                }
                self.navigationController?.pushViewController(self.articleListController, animated: true)
            })
            return [preview]
        case .Tags:
            if indexPath.row == feed?.tags.count {
                return nil
            }
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
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
            let editTitle = NSLocalizedString("Generic_Edit", comment: "")
            let edit = UITableViewRowAction(style: .Normal, title: editTitle, handler: {(_, indexPath) in
                self.showTagEditor(indexPath.row)
            })
            return [delete, edit]
        default:
            return nil
        }
    }
}

extension QueryFeedViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableView.separatorColor = themeRepository.textColor
        self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle

        self.navigationController?.navigationBar.barStyle = themeRepository.barStyle
    }
}

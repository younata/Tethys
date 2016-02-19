import UIKit
import PureLayout
import SafariServices
import Ra
import rNewsKit

// swiftlint:disable file_length

public class SettingsViewController: UIViewController, Injectable {
    private enum SettingsSection: CustomStringConvertible {
        case Theme
        case QuickActions
        case Advanced
        case Credits

        private init?(rawValue: Int, traits: UITraitCollection) {
            if rawValue == 0 {
                self = .Theme
                return
            } else {
                let offset: Int
                if #available(iOS 9, *) {
                    if traits.forceTouchCapability == .Available {
                        offset = 0
                    } else {
                        offset = 1
                    }
                } else {
                    offset = 1
                }
                switch rawValue + offset {
                case 1:
                    self = .QuickActions
                case 2:
                    self = .Advanced
                case 3:
                    self = .Credits
                default:
                    return nil
                }
            }
        }

        static func numberOfSettings(traits: UITraitCollection) -> Int {
            if #available(iOS 9, *) {
                if traits.forceTouchCapability == .Available {
                    return 4
                }
            }
            return 3
        }

        private var rawValue: Int {
            let offset: Int
            if #available(iOS 9, *) {
                offset = 1
            } else {
                offset = 0
            }
            switch self {
            case .Theme: return 0
            case .QuickActions: return 1
            case .Advanced: return 1 + offset
            case .Credits: return 2 + offset
            }
        }

        private var description: String {
            switch self {
            case .Theme:
                return NSLocalizedString("SettingsViewController_Table_Header_Theme", comment: "")
            case .QuickActions:
                return NSLocalizedString("SettingsViewController_Table_Header_QuickActions", comment: "")
            case .Advanced:
                return NSLocalizedString("SettingsViewController_Table_Header_Advanced", comment: "")
            case .Credits:
                return NSLocalizedString("SettingsViewController_Table_Header_Credits", comment: "")
            }
        }
    }

    public let tableView = UITableView(frame: CGRect.zero, style: .Grouped)

    private let themeRepository: ThemeRepository
    private let settingsRepository: SettingsRepository
    private let urlOpener: UrlOpener
    private let quickActionRepository: QuickActionRepository
    private let feedRepository: FeedRepository
    private let documentationViewController: Void -> DocumentationViewController

    private var oldTheme: ThemeRepository.Theme = .Default
    private lazy var queryFeedsEnabled: Bool = {
        return self.settingsRepository.queryFeedsEnabled
    }()

    // swiftlint:disable function_parameter_count
    public init(themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                urlOpener: UrlOpener,
                quickActionRepository: QuickActionRepository,
                feedRepository: FeedRepository,
                documentationViewController: Void -> DocumentationViewController) {
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.urlOpener = urlOpener
        self.quickActionRepository = quickActionRepository
        self.feedRepository = feedRepository
        self.documentationViewController = documentationViewController

        super.init(nibName: nil, bundle: nil)
    }
    // swiftlint:enable function_parameter_count

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(ThemeRepository)!,
            settingsRepository: injector.create(SettingsRepository)!,
            urlOpener: injector.create(UrlOpener)!,
            quickActionRepository: injector.create(QuickActionRepository)!,
            feedRepository: injector.create(FeedRepository)!,
            documentationViewController: {injector.create(DocumentationViewController)!}
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("SettingsViewController_Title", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Save,
            target: self,
            action: "didTapSave")
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel,
            target: self,
            action: "didTapDismiss")

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.registerClass(SwitchTableViewCell.self, forCellReuseIdentifier: "switch")

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.allowsMultipleSelection = true

        self.themeRepository.addSubscriber(self)

        let selectedIndexPath = NSIndexPath(forRow: self.themeRepository.theme.rawValue,
            inSection: SettingsSection.Theme.rawValue)
        self.tableView.selectRowAtIndexPath(selectedIndexPath, animated: false, scrollPosition: .None)

        self.oldTheme = self.themeRepository.theme
    }

    public override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        self.splitViewController?.setNeedsStatusBarAppearanceUpdate()
    }

    public override func canBecomeFirstResponder() -> Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = []

        for (idx, theme) in ThemeRepository.Theme.array().enumerate() {
            guard theme != self.themeRepository.theme else {
                continue
            }

            let keyCommand = UIKeyCommand(input: "\(idx+1)", modifierFlags: .Command, action: "didHitChangeTheme:")
            if #available(iOS 9, *) {
                let title = NSLocalizedString("SettingsViewController_Commands_Theme", comment: "")
                keyCommand.discoverabilityTitle = String(NSString.localizedStringWithFormat(title, theme.description))
            }
            commands.append(keyCommand)
        }

        let save = UIKeyCommand(input: "s", modifierFlags: .Command, action: "didTapSave")
        let dismiss = UIKeyCommand(input: "w", modifierFlags: .Command, action: "didTapDismiss")

        if #available(iOS 9, *) {
            save.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Save", comment: "")
            dismiss.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Dismiss", comment: "")
        }

        commands.append(save)
        commands.append(dismiss)

        return commands
    }

    internal func didHitChangeTheme(keyCommand: UIKeyCommand) {}

    internal func didTapDismiss() {
        if self.oldTheme != self.themeRepository.theme {
            self.themeRepository.theme = self.oldTheme
        }
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    internal func didTapSave() {
        self.oldTheme = self.themeRepository.theme
        self.settingsRepository.queryFeedsEnabled = self.queryFeedsEnabled
        self.didTapDismiss()
    }

    private func titleForQuickAction(row: Int) -> String {
        guard #available(iOS 9, *) else { return "" }

        let quickActions = self.quickActionRepository.quickActions
        if row >= quickActions.count {
            let title: String
            if quickActions.count == 0 {
                title = NSLocalizedString("SettingsViewController_QuickActions_AddFirst", comment: "")
            } else {
                title = NSLocalizedString("SettingsViewController_QuickActions_AddAdditional", comment: "")
            }
            return title
        } else {
            let action = quickActions[row]
            return action.localizedTitle
        }
    }

    private func feedForQuickAction(row: Int, feeds: [Feed]) -> Feed? {
        guard #available(iOS 9, *) else { return nil }

        let quickActions = self.quickActionRepository.quickActions
        guard row < quickActions.count else { return nil }

        let quickAction = quickActions[row]

        return feeds.filter({$0.title == quickAction.localizedTitle}).first
    }
}

extension SettingsViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
        self.view.backgroundColor = self.themeRepository.backgroundColor

        func colorWithDefault(color: UIColor) -> UIColor? {
            return self.themeRepository.theme == .Default ? nil : color
        }

        self.tableView.backgroundColor = colorWithDefault(self.themeRepository.backgroundColor)
        for section in 0..<self.tableView.numberOfSections {
            let headerView = self.tableView.headerViewForSection(section)
            headerView?.textLabel?.textColor = colorWithDefault(self.themeRepository.tintColor)
        }
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return SettingsSection.numberOfSettings(self.traitCollection)
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        guard let section = SettingsSection(rawValue: sectionNum, traits: self.traitCollection) else {
            return 0
        }
        switch section {
        case .Theme:
            return 2
        case .QuickActions:
            if #available(iOS 9, *) {
                if self.quickActionRepository.quickActions.count == 3 {
                    return 3
                }
                return self.quickActionRepository.quickActions.count + 1
            }
            return 0
        case .Advanced:
            return 1
        case .Credits:
            return 1
        }
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection) else {
            return TableViewCell()
        }
        switch section {
        case .Theme:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            guard let theme = ThemeRepository.Theme(rawValue: indexPath.row) else {
                return cell
            }
            cell.themeRepository = self.themeRepository
            cell.textLabel?.text = theme.description
            return cell
        case .QuickActions:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            cell.themeRepository = self.themeRepository

            cell.textLabel?.text = self.titleForQuickAction(indexPath.row)

            return cell
        case .Advanced:
            let cell = tableView.dequeueReusableCellWithIdentifier("switch",
                forIndexPath: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Advanced_EnableQueryFeeds", comment: "")
            cell.themeRepository = self.themeRepository
            cell.onTapSwitch = {_ in }
            cell.theSwitch.on = self.queryFeedsEnabled
            cell.onTapSwitch = {aSwitch in
                self.queryFeedsEnabled = aSwitch.on
                self.navigationItem.rightBarButtonItem?.enabled = true
            }
            return cell
        case .Credits:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            cell.themeRepository = self.themeRepository
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Name", comment: "")
            cell.detailTextLabel?.text =
                NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Detail", comment: "")
            return cell
        }
    }

    public func tableView(tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        guard let section = SettingsSection(rawValue: sectionNum, traits: self.traitCollection) else {
            return nil
        }
        return section.description
    }
}

extension SettingsViewController: UITableViewDelegate {
    public func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection) else {
            return
        }

        if section == .Theme {
            tableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: .None)
        }
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection)
            where section == .QuickActions else { return false }
        guard #available(iOS 9, *) else { return false }
        return indexPath.row < self.quickActionRepository.quickActions.count
    }

    public func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            guard self.tableView(tableView, canEditRowAtIndexPath: indexPath) else { return nil }
            guard #available(iOS 9, *) else { return nil }
            let deleteAction = UITableViewRowAction(style: .Default,
                title: NSLocalizedString("Generic_Delete", comment: "")) {_, indexPath in
                    self.quickActionRepository.quickActions.removeAtIndex(indexPath.row)
                    if self.quickActionRepository.quickActions.count != 2 {
                        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                    } else {
                        tableView.reloadRowsAtIndexPaths([
                                indexPath, NSIndexPath(forRow: 2, inSection: indexPath.section)
                            ], withRowAnimation: .Automatic)
                    }
            }
            return [deleteAction]
    }

    public func tableView(tableView: UITableView,
        commitEditingStyle editingStyle: UITableViewCellEditingStyle,
        forRowAtIndexPath indexPath: NSIndexPath) {}

    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection) else { return }
        switch section {
        case .Theme:
            guard let theme = ThemeRepository.Theme(rawValue: indexPath.row) else { return }
            self.themeRepository.theme = theme
            self.navigationItem.rightBarButtonItem?.enabled = true
            self.tableView.reloadData()
            self.tableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: .None)
        case .QuickActions:
            guard #available(iOS 9, *) else { return }
            let feedsListController = FeedsListController()
            feedsListController.themeRepository = self.themeRepository
            feedsListController.navigationItem.title = self.titleForQuickAction(indexPath.row)

            let quickActions = self.quickActionRepository.quickActions
            self.feedRepository.feeds {feeds in
                if !quickActions.isEmpty {
                    let quickActionFeeds = quickActions.indices.reduce([Feed]()) {
                        guard let feed = self.feedForQuickAction($1, feeds: feeds) else { return $0 }
                        return $0 + [feed]
                    }
                    feedsListController.feeds = feeds.filter { !quickActionFeeds.contains($0) }
                } else {
                    feedsListController.feeds = feeds
                }
            }
            feedsListController.tapFeed = {feed, _ in
                let newQuickAction = UIApplicationShortcutItem(type: "com.rachelbrindle.rssclient.viewfeed",
                    localizedTitle: feed.title)
                if indexPath.row < quickActions.count {
                    self.quickActionRepository.quickActions[indexPath.row] = newQuickAction
                } else {
                    self.quickActionRepository.quickActions.append(newQuickAction)
                    if self.quickActionRepository.quickActions.count <= 3 {
                        let quickActionsCount = self.quickActionRepository.quickActions.count
                        let insertedIndexPath = NSIndexPath(forRow: quickActionsCount, inSection: indexPath.section)
                        self.tableView.insertRowsAtIndexPaths([insertedIndexPath], withRowAnimation: .Automatic)
                    }
                }
                self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                self.navigationController?.popViewControllerAnimated(true)
            }
            self.navigationController?.pushViewController(feedsListController, animated: true)
        case .Advanced:
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            let documentationViewController = self.documentationViewController()
            documentationViewController.configure(.QueryFeed)
            self.navigationController?.pushViewController(documentationViewController, animated: true)
        case .Credits:
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            guard let url = NSURL(string: "https://twitter.com/younata") else { return }
            if #available(iOS 9.0, *) {
                let viewController = SFSafariViewController(URL: url)
                self.presentViewController(viewController, animated: true, completion: nil)
            } else {
                self.urlOpener.openURL(url)
            }
        }
    }
}

import UIKit
import PureLayout
import SafariServices
import Ra
import Result
import rNewsKit

// swiftlint:disable file_length

extension Account: CustomStringConvertible {
    public var description: String {
        switch self {
        case .Pasiphae:
            return NSLocalizedString("SettingsViewController_Accounts_Pasiphae", comment: "")
        }
    }
}

public class SettingsViewController: UIViewController, Injectable {
    private enum SettingsSection: CustomStringConvertible {
        case Theme
        case QuickActions
        case Accounts
        case Advanced
        case Credits

        private init?(rawValue: Int, traits: UITraitCollection) {
            if rawValue == 0 {
                self = .Theme
                return
            } else {
                let offset: Int
                switch traits.forceTouchCapability {
                case .Available:
                    offset = 0
                case .Unavailable, .Unknown:
                    offset = 1
                }
                switch rawValue + offset {
                case 1:
                    self = .QuickActions
                case 2:
                    self = .Accounts
                case 3:
                    self = .Advanced
                case 4:
                    self = .Credits
                default:
                    return nil
                }
            }
        }

        static func numberOfSettings(traits: UITraitCollection) -> Int {
            if traits.forceTouchCapability == .Available {
                return 5
            }
            return 4
        }

        private var rawValue: Int {
            switch self {
            case .Theme: return 0
            case .QuickActions: return 1
            case .Accounts: return 2
            case .Advanced: return 3
            case .Credits: return 4
            }
        }

        private var description: String {
            switch self {
            case .Theme:
                return NSLocalizedString("SettingsViewController_Table_Header_Theme", comment: "")
            case .QuickActions:
                return NSLocalizedString("SettingsViewController_Table_Header_QuickActions", comment: "")
            case .Accounts:
                return NSLocalizedString("SettinsgViewController_Table_Header_Accounts", comment: "")
            case .Advanced:
                return NSLocalizedString("SettingsViewController_Table_Header_Advanced", comment: "")
            case .Credits:
                return NSLocalizedString("SettingsViewController_Table_Header_Credits", comment: "")
            }
        }
    }

    private enum AdvancedSection: Int, CustomStringConvertible {
        case ShowReadingTimes = 0

        private var description: String {
            switch self {
            case .ShowReadingTimes:
                return NSLocalizedString("SettingsViewController_Advanced_ShowReadingTimes", comment: "")
            }
        }

        private static let numberOfOptions = 1
    }

    public let tableView = UITableView(frame: CGRect.zero, style: .Grouped)

    private let themeRepository: ThemeRepository
    private let settingsRepository: SettingsRepository
    private let quickActionRepository: QuickActionRepository
    private let databaseUseCase: DatabaseUseCase
    private let accountRepository: AccountRepository
    private let loginViewController: Void -> LoginViewController

    private var oldTheme: ThemeRepository.Theme = .Default

    private lazy var showReadingTimes: Bool = {
        return self.settingsRepository.showEstimatedReadingLabel
    }()

    // swiftlint:disable function_parameter_count
    public init(themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                quickActionRepository: QuickActionRepository,
                databaseUseCase: DatabaseUseCase,
                accountRepository: AccountRepository,
                loginViewController: Void -> LoginViewController) {
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.quickActionRepository = quickActionRepository
        self.databaseUseCase = databaseUseCase
        self.accountRepository = accountRepository
        self.loginViewController = loginViewController

        super.init(nibName: nil, bundle: nil)
    }
    // swiftlint:enable function_parameter_count

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(ThemeRepository)!,
            settingsRepository: injector.create(SettingsRepository)!,
            quickActionRepository: injector.create(QuickActionRepository)!,
            databaseUseCase: injector.create(DatabaseUseCase)!,
            accountRepository: injector.create(AccountRepository)!,
            loginViewController: { injector.create(LoginViewController)! }
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
            action: #selector(SettingsViewController.didTapSave))
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel,
            target: self,
            action: #selector(SettingsViewController.didTapDismiss))

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.registerClass(SwitchTableViewCell.self, forCellReuseIdentifier: "switch")

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.allowsMultipleSelection = true

        self.themeRepository.addSubscriber(self)

        self.oldTheme = self.themeRepository.theme
        self.reloadTable()
    }

    public override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        self.splitViewController?.setNeedsStatusBarAppearanceUpdate()
        self.reloadTable()
    }

    public override func traitCollectionDidChange(previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        self.reloadTable()
    }

    public override func canBecomeFirstResponder() -> Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = []

        for (idx, theme) in ThemeRepository.Theme.array().enumerate() {
            guard theme != self.themeRepository.theme else {
                continue
            }

            let keyCommand = UIKeyCommand(input: "\(idx+1)", modifierFlags: .Command,
                                          action: #selector(SettingsViewController.didHitChangeTheme(_:)))
            let title = NSLocalizedString("SettingsViewController_Commands_Theme", comment: "")
            keyCommand.discoverabilityTitle = String(NSString.localizedStringWithFormat(title, theme.description))
            commands.append(keyCommand)
        }

        let save = UIKeyCommand(input: "s", modifierFlags: .Command,
                                action: #selector(SettingsViewController.didTapSave))
        let dismiss = UIKeyCommand(input: "w", modifierFlags: .Command,
                                   action: #selector(SettingsViewController.didTapDismiss))

        save.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Save", comment: "")
        dismiss.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Dismiss", comment: "")

        commands.append(save)
        commands.append(dismiss)

        return commands
    }

    @objc private func didHitChangeTheme(keyCommand: UIKeyCommand) {}

    @objc private func didTapDismiss() {
        if self.oldTheme != self.themeRepository.theme {
            self.themeRepository.theme = self.oldTheme
        }
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    @objc private func didTapSave() {
        self.oldTheme = self.themeRepository.theme
        self.settingsRepository.showEstimatedReadingLabel = self.showReadingTimes
        self.didTapDismiss()
    }

    private func reloadTable() {
        self.tableView.reloadData()
        let selectedIndexPath = NSIndexPath(forRow: self.themeRepository.theme.rawValue,
                                            inSection: SettingsSection.Theme.rawValue)
        self.tableView.selectRowAtIndexPath(selectedIndexPath, animated: false, scrollPosition: .None)
    }

    private func titleForQuickAction(row: Int) -> String {
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
        let quickActions = self.quickActionRepository.quickActions
        guard row < quickActions.count else { return nil }

        let quickAction = quickActions[row]

        return feeds.objectPassingTest({$0.title == quickAction.localizedTitle})
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
            if self.quickActionRepository.quickActions.count == 3 {
                return 3
            }
            return self.quickActionRepository.quickActions.count + 1
        case .Accounts:
            return 1
        case .Advanced:
            return AdvancedSection.numberOfOptions
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
        case .Accounts:
            let cell = tableView.dequeueReusableCellWithIdentifier("cell", forIndexPath: indexPath) as! TableViewCell
            cell.themeRepository = self.themeRepository

            let row = Account(rawValue: indexPath.row)!
            cell.textLabel?.text = row.description
            cell.detailTextLabel?.text = self.accountRepository.loggedIn()

            return cell
        case .Advanced:
            let cell = tableView.dequeueReusableCellWithIdentifier("switch",
                forIndexPath: indexPath) as! SwitchTableViewCell
            let row = AdvancedSection(rawValue: indexPath.row)!
            cell.textLabel?.text = row.description
            cell.themeRepository = self.themeRepository
            cell.onTapSwitch = {_ in }
            switch row {
            case .ShowReadingTimes:
                cell.theSwitch.on = self.showReadingTimes
                cell.onTapSwitch = {aSwitch in
                    self.showReadingTimes = aSwitch.on
                    self.navigationItem.rightBarButtonItem?.enabled = true
                }
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
            where section == .QuickActions || section == .Accounts else { return false }
        if section == .QuickActions {
            return indexPath.row < self.quickActionRepository.quickActions.count
        }
        return true
    }

    public func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        guard self.tableView(tableView, canEditRowAtIndexPath: indexPath) else { return nil }

        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection) else {return nil}
        switch section {
        case .QuickActions:
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let deleteAction = UITableViewRowAction(style: .Default, title: deleteTitle) {_, indexPath in
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
        case .Accounts:
            guard self.accountRepository.loggedIn() != nil else { return [] }
            let logOutTitle = NSLocalizedString("SettingsViewController_Accounts_Log_Out", comment: "")
            let logOutAction = UITableViewRowAction(style: .Default, title: logOutTitle) {_ in
                self.accountRepository.logOut()
                tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
            }
            return [logOutAction]
        default:
            return nil
        }
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
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            self.didTapQuickActionCell(indexPath)
        case .Accounts:
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            let loginViewController = self.loginViewController()
            loginViewController.accountType = Account(rawValue: indexPath.row)
            self.navigationController?.pushViewController(loginViewController, animated: true)
        case .Advanced:
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
        case .Credits:
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            guard let url = NSURL(string: "https://twitter.com/younata") else { return }
            let viewController = SFSafariViewController(URL: url)
            self.presentViewController(viewController, animated: true, completion: nil)
        }
    }

    private func didTapQuickActionCell(indexPath: NSIndexPath) {
        let feedsListController = FeedsListController()
        feedsListController.themeRepository = self.themeRepository
        feedsListController.navigationItem.title = self.titleForQuickAction(indexPath.row)

        let quickActions = self.quickActionRepository.quickActions
        self.databaseUseCase.feeds().then {
            if case let Result.Success(feeds) = $0 {
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
    }
}

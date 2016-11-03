import UIKit
import PureLayout
import SafariServices
import Ra
import Result
import rNewsKit

// swiftlint:disable file_length

public final class SettingsViewController: UIViewController, Injectable {
    public let tableView = UITableView(frame: CGRect.zero, style: .grouped)

    fileprivate let themeRepository: ThemeRepository
    fileprivate let settingsRepository: SettingsRepository
    fileprivate let quickActionRepository: QuickActionRepository
    fileprivate let databaseUseCase: DatabaseUseCase
    fileprivate let accountRepository: AccountRepository
    fileprivate let opmlService: OPMLService
    fileprivate let mainQueue: OperationQueue
    fileprivate let loginViewController: (Void) -> LoginViewController
    fileprivate let documentationViewController: (Void) -> DocumentationViewController

    fileprivate var oldTheme: ThemeRepository.Theme = .default

    fileprivate lazy var showReadingTimes: Bool = { return self.settingsRepository.showEstimatedReadingLabel }()
    fileprivate lazy var refreshControlStyle: RefreshControlStyle = { return self.settingsRepository.refreshControl }()

    // swiftlint:disable function_parameter_count
    public init(themeRepository: ThemeRepository,
                settingsRepository: SettingsRepository,
                quickActionRepository: QuickActionRepository,
                databaseUseCase: DatabaseUseCase,
                accountRepository: AccountRepository,
                opmlService: OPMLService,
                mainQueue: OperationQueue,
                loginViewController: @escaping (Void) -> LoginViewController,
                documentationViewController: @escaping (Void) -> DocumentationViewController) {
        self.themeRepository = themeRepository
        self.settingsRepository = settingsRepository
        self.quickActionRepository = quickActionRepository
        self.databaseUseCase = databaseUseCase
        self.accountRepository = accountRepository
        self.opmlService = opmlService
        self.mainQueue = mainQueue
        self.loginViewController = loginViewController
        self.documentationViewController = documentationViewController

        super.init(nibName: nil, bundle: nil)
    }
    // swiftlint:enable function_parameter_count

    public required convenience init(injector: Injector) {
        self.init(
            themeRepository: injector.create(kind: ThemeRepository.self)!,
            settingsRepository: injector.create(kind: SettingsRepository.self)!,
            quickActionRepository: injector.create(kind: QuickActionRepository.self)!,
            databaseUseCase: injector.create(kind: DatabaseUseCase.self)!,
            accountRepository: injector.create(kind: AccountRepository.self)!,
            opmlService: injector.create(kind: OPMLService.self)!,
            mainQueue: injector.create(string: kMainQueue) as! OperationQueue,
            loginViewController: { injector.create(kind: LoginViewController.self)! },
            documentationViewController: { injector.create(kind: DocumentationViewController.self)! }
        )
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("SettingsViewController_Title", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save,
            target: self,
            action: #selector(SettingsViewController.didTapSave))
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
            target: self,
            action: #selector(SettingsViewController.didTapDismiss))

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)

        self.tableView.register(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "switch")

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.allowsMultipleSelection = true

        self.themeRepository.addSubscriber(self)

        self.registerForPreviewing(with: self, sourceView: self.tableView)

        self.oldTheme = self.themeRepository.theme
        self.reloadTable()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.splitViewController?.setNeedsStatusBarAppearanceUpdate()
        self.reloadTable()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        self.reloadTable()
    }

    public override var canBecomeFirstResponder: Bool { return true }

    public override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = []

        for (idx, theme) in ThemeRepository.Theme.array().enumerated() {
            guard theme != self.themeRepository.theme else {
                continue
            }

            let keyCommand = UIKeyCommand(input: "\(idx+1)", modifierFlags: .command,
                                          action: #selector(SettingsViewController.didHitChangeTheme(_:)))
            let title = NSLocalizedString("SettingsViewController_Commands_Theme", comment: "")
            keyCommand.discoverabilityTitle = String(NSString.localizedStringWithFormat(title as NSString,
                                                                                        theme.description))
            commands.append(keyCommand)
        }

        let save = UIKeyCommand(input: "s", modifierFlags: .command,
                                action: #selector(SettingsViewController.didTapSave))
        let dismiss = UIKeyCommand(input: "w", modifierFlags: .command,
                                   action: #selector(SettingsViewController.didTapDismiss))

        save.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Save", comment: "")
        dismiss.discoverabilityTitle = NSLocalizedString("SettingsViewController_Commands_Dismiss", comment: "")

        commands.append(save)
        commands.append(dismiss)

        return commands
    }

    @objc fileprivate func didHitChangeTheme(_ keyCommand: UIKeyCommand) {}

    @objc fileprivate func didTapDismiss() {
        if self.oldTheme != self.themeRepository.theme {
            self.themeRepository.theme = self.oldTheme
        }
        self.navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc fileprivate func didTapSave() {
        self.oldTheme = self.themeRepository.theme
        self.settingsRepository.showEstimatedReadingLabel = self.showReadingTimes
        self.settingsRepository.refreshControl = self.refreshControlStyle
        self.didTapDismiss()
    }

    fileprivate func reloadTable() {
        self.tableView.reloadData()
        let currentThemeIndexPath = IndexPath(row: self.themeRepository.theme.rawValue,
                                              section: SettingsSection.theme.rawValue)
        let currentRefreshStyleIndexPath = IndexPath(row: self.refreshControlStyle.rawValue,
                                                     section: SettingsSection.refresh.rawValue)
        self.tableView.selectRow(at: currentThemeIndexPath, animated: false, scrollPosition: .none)
        self.tableView.selectRow(at: currentRefreshStyleIndexPath, animated: false, scrollPosition: .none)

    }

    fileprivate func titleForQuickAction(_ row: Int) -> String {
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

    fileprivate func feedForQuickAction(_ row: Int, feeds: [Feed]) -> Feed? {
        let quickActions = self.quickActionRepository.quickActions
        guard row < quickActions.count else { return nil }

        let quickAction = quickActions[row]

        return feeds.objectPassingTest({$0.title == quickAction.localizedTitle})
    }
}

extension SettingsViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: self.themeRepository.textColor
        ]
        self.view.backgroundColor = self.themeRepository.backgroundColor

        func colorWithDefault(_ color: UIColor) -> UIColor? {
            return self.themeRepository.theme == .default ? nil : color
        }

        self.tableView.backgroundColor = colorWithDefault(self.themeRepository.backgroundColor)
        for section in 0..<self.tableView.numberOfSections {
            let headerView = self.tableView.headerView(forSection: section)
            headerView?.textLabel?.textColor = colorWithDefault(self.themeRepository.tintColor)
        }
    }
}

extension SettingsViewController: UIViewControllerPreviewingDelegate {
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                                  viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = self.tableView.indexPathForRow(at: location),
            let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection) else {
                return nil
        }
        switch section {
        case .quickActions:
            let feedsListController = FeedsListController()
            feedsListController.themeRepository = self.themeRepository
            feedsListController.navigationItem.title = self.titleForQuickAction(indexPath.row)

            let quickActions = self.quickActionRepository.quickActions
            _ = self.databaseUseCase.feeds().then {
                if case let Result.success(feeds) = $0 {
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
            if indexPath.row < self.quickActionRepository.quickActions.count {
                let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
                feedsListController._previewActionItems = [
                    UIPreviewAction(title: deleteTitle, style: .destructive) { _ in
                        self.quickActionRepository.quickActions.remove(at: indexPath.row)
                        if self.quickActionRepository.quickActions.count != 2 {
                            self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        } else {
                            self.tableView.reloadRows(at: [
                                indexPath, IndexPath(row: 2, section: indexPath.section)
                                ], with: .automatic)
                        }
                    }
                ]
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
                        let insertedIndexPath = IndexPath(row: quickActionsCount, section: indexPath.section)
                        self.tableView.insertRows(at: [insertedIndexPath], with: .automatic)
                    }
                }
                self.tableView.reloadRows(at: [indexPath], with: .automatic)
                _ = self.navigationController?.popViewController(animated: true)
            }
            return feedsListController
            //self.navigationController?.pushViewController(feedsListController, animated: true)
        default:
            return nil
        }
    }

    public func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                                  commit viewControllerToCommit: UIViewController) {
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.numberOfSettings(self.traitCollection)
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        guard let section = SettingsSection(rawValue: sectionNum, traits: self.traitCollection) else {
            return 0
        }
        switch section {
        case .theme:
            return 2
        case .refresh:
            return 2
        case .quickActions:
            if self.quickActionRepository.quickActions.count == 3 {
                return 3
            }
            return self.quickActionRepository.quickActions.count + 1
        case .accounts:
            return 1
        case .other:
            return OtherSection.numberOfOptions
        case .credits:
            return 2
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection) else {
            return TableViewCell()
        }
        switch section {
        case .theme:
            return self.themeCell(indexPath: indexPath)
        case .refresh:
            return self.refreshCell(indexPath: indexPath)
        case .quickActions:
            return self.quickActionCell(indexPath: indexPath)
        case .accounts:
            return self.accountCell(indexPath: indexPath)
        case .other:
            return self.otherCell(indexPath: indexPath)
        case .credits:
            return self.creditCell(indexPath: indexPath)
        }
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        guard let section = SettingsSection(rawValue: sectionNum, traits: self.traitCollection) else { return nil }
        return section.description
    }

    private func themeCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        guard let theme = ThemeRepository.Theme(rawValue: indexPath.row) else { return cell }
        cell.themeRepository = self.themeRepository
        cell.textLabel?.text = theme.description
        return cell
    }

    private func refreshCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        guard let refreshStyle = RefreshControlStyle(rawValue: indexPath.row) else { return cell }
        cell.themeRepository = self.themeRepository
        cell.textLabel?.text = refreshStyle.description
        return cell
    }

    private func quickActionCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        cell.themeRepository = self.themeRepository
        cell.textLabel?.text = self.titleForQuickAction(indexPath.row)
        return cell
    }

    private func accountCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        cell.themeRepository = self.themeRepository

        let row = Account(rawValue: indexPath.row)!
        cell.textLabel?.text = row.description
        cell.detailTextLabel?.text = self.accountRepository.loggedIn()

        return cell
    }

    private func otherCell(indexPath: IndexPath) -> UITableViewCell {
        let row = OtherSection(rawValue: indexPath.row)!
        var tableCell: UITableViewCell
        switch row {
        case .showReadingTimes:
            let cell = tableView.dequeueReusableCell(withIdentifier: "switch",
                                                     for: indexPath) as! SwitchTableViewCell
            cell.themeRepository = self.themeRepository
            cell.onTapSwitch = {_ in }
            cell.theSwitch.isOn = self.showReadingTimes
            cell.onTapSwitch = {aSwitch in
                self.showReadingTimes = aSwitch.isOn
                self.navigationItem.rightBarButtonItem?.isEnabled = true
            }
            tableCell = cell
        case .exportOPML:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
            cell.themeRepository = self.themeRepository
            tableCell = cell
        }
        tableCell.textLabel?.text = row.description
        return tableCell
    }

    private func creditCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        cell.themeRepository = self.themeRepository
        if indexPath.row == 0 {
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Name", comment: "")
            cell.detailTextLabel?.text = NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Detail",
                                                           comment: "")
        } else if indexPath.row == 1 {
            cell.textLabel?.text = NSLocalizedString("SettingsViewController_Credits_Libraries", comment: "")
            cell.detailTextLabel?.text = ""
        }
        return cell
    }
}

extension SettingsViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection) else { return }

        switch section {
        case .theme:
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        case .refresh:
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        default:
            break
        }
    }

    @objc(tableView:canEditRowAtIndexPath:) public func tableView(_ tableView: UITableView,
                                                                  canEditRowAt indexPath: IndexPath) -> Bool {
        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection),
            section == .quickActions || section == .accounts else { return false }
        if section == .quickActions { return indexPath.row < self.quickActionRepository.quickActions.count }
        return true
    }

    public func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard self.tableView(tableView, canEditRowAt: indexPath) else { return nil }

        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection) else {return nil}
        switch section {
        case .quickActions:
            let deleteTitle = NSLocalizedString("Generic_Delete", comment: "")
            let deleteAction = UITableViewRowAction(style: .default, title: deleteTitle) {_, indexPath in
                self.quickActionRepository.quickActions.remove(at: indexPath.row)
                if self.quickActionRepository.quickActions.count != 2 {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                } else {
                    tableView.reloadRows(at: [
                        indexPath, IndexPath(row: 2, section: indexPath.section)
                        ], with: .automatic)
                }
            }
            return [deleteAction]
        case .accounts:
            guard self.accountRepository.loggedIn() != nil else { return [] }
            let logOutTitle = NSLocalizedString("SettingsViewController_Accounts_Log_Out", comment: "")
            let logOutAction = UITableViewRowAction(style: .default, title: logOutTitle) {_ in
                self.accountRepository.logOut()
                tableView.reloadRows(at: [indexPath], with: .left)
            }
            return [logOutAction]
        default:
            return nil
        }
    }

    @objc(tableView:commitEditingStyle:forRowAtIndexPath:) public func tableView(_ tableView: UITableView,
        commit editingStyle: UITableViewCellEditingStyle,
        forRowAt indexPath: IndexPath) {}

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section, traits: self.traitCollection) else { return }
        switch section {
        case .theme:
            self.didTapThemeCell(indexPath: indexPath)
        case .refresh:
            self.didTapRefreshCell(indexPath: indexPath)
        case .quickActions:
            self.didTapQuickActionCell(tableView: tableView, indexPath: indexPath)
        case .accounts:
            self.didTapAccountCell(tableView: tableView, indexPath: indexPath)
        case .other:
            self.didTapOtherCell(tableView: tableView, indexPath: indexPath)
        case .credits:
            self.didTapCreditCell(tableView: tableView, indexPath: indexPath)
        }
    }

    private func didTapThemeCell(indexPath: IndexPath) {
        guard let theme = ThemeRepository.Theme(rawValue: indexPath.row) else { return }
        self.themeRepository.theme = theme
        self.navigationItem.rightBarButtonItem?.isEnabled = true
        self.reloadTable()
    }

    private func didTapRefreshCell(indexPath: IndexPath) {
        guard let refreshControlStyle = RefreshControlStyle(rawValue: indexPath.row) else { return }
        self.refreshControlStyle = refreshControlStyle
        self.navigationItem.rightBarButtonItem?.isEnabled = true
        self.reloadTable()
    }

    private func didTapQuickActionCell(tableView: UITableView, indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let feedsListController = FeedsListController()
        feedsListController.themeRepository = self.themeRepository
        feedsListController.navigationItem.title = self.titleForQuickAction(indexPath.row)

        let quickActions = self.quickActionRepository.quickActions
        _ = self.databaseUseCase.feeds().then {
            if case let Result.success(feeds) = $0 {
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
                    let insertedIndexPath = IndexPath(row: quickActionsCount, section: indexPath.section)
                    self.tableView.insertRows(at: [insertedIndexPath], with: .automatic)
                }
            }
            self.tableView.reloadRows(at: [indexPath], with: .automatic)
            _ = self.navigationController?.popViewController(animated: true)
        }
        self.navigationController?.pushViewController(feedsListController, animated: true)
    }

    private func didTapAccountCell(tableView: UITableView, indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let loginViewController = self.loginViewController()
        loginViewController.accountType = Account(rawValue: indexPath.row)
        self.navigationController?.pushViewController(loginViewController, animated: true)
    }

    private func didTapOtherCell(tableView: UITableView, indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let otherSection = OtherSection(rawValue: indexPath.row) else { return }

        switch otherSection {
        case .exportOPML:
            _ = self.opmlService.writeOPML().then {
                switch $0 {
                case let .success(url):
                    self.mainQueue.addOperation {
                        let shareSheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        self.present(shareSheet, animated: true, completion: nil)
                    }
                case .failure(_):
                    self.mainQueue.addOperation {
                        let alertTitle = NSLocalizedString("SettingsViewController_Other_ExportOPML_Error_Title",
                                                           comment: "")
                        let alertMsg = NSLocalizedString("SettingsViewController_Other_ExportOPML_Error_Message",
                                                         comment: "")
                        let alert = UIAlertController(title: alertTitle,
                                                      message: alertMsg,
                                                      preferredStyle: .alert)
                        let dismissTitle = NSLocalizedString("Generic_Ok", comment: "")
                        alert.addAction(UIAlertAction(title: dismissTitle, style: .default) { _ in
                            self.dismiss(animated: true, completion: nil)
                        })
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        default:
            break
        }
    }

    private func didTapCreditCell(tableView: UITableView, indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath.row == 0 {
            guard let url = URL(string: "https://twitter.com/younata") else { return }
            let viewController = SFSafariViewController(url: url)
            self.present(viewController, animated: true, completion: nil)
        } else if indexPath.row == 1 {
            let viewController = self.documentationViewController()
            viewController.configure(documentation: .libraries)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }
}

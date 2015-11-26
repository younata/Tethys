import UIKit
import PureLayout
import SafariServices

public class SettingsViewController: UIViewController {
    private enum SettingsSection: Int, CustomStringConvertible {
        case Theme = 0
        case Advanced = 1
        case Credits = 2

        private var description: String {
            switch self {
            case .Theme:
                return NSLocalizedString("SettingsViewController_Table_Header_Theme", comment: "")
            case .Advanced:
                return NSLocalizedString("SettingsViewController_Table_Header_Advanced", comment: "")
            case .Credits:
                return NSLocalizedString("SettingsViewController_Table_Header_Credits", comment: "")
            }
        }
    }

    public lazy var userDefaults = NSUserDefaults.standardUserDefaults()

    public let tableView = UITableView(frame: CGRectZero, style: .Grouped)

    private lazy var themeRepository: ThemeRepository = {
        return self.injector!.create(ThemeRepository.self) as! ThemeRepository
    }()

    private lazy var settingsRepository: SettingsRepository = {
        return self.injector!.create(SettingsRepository.self) as! SettingsRepository
    }()

    private lazy var queryFeedsEnabled: Bool = {
        return self.settingsRepository.queryFeedsEnabled
    }()

    private lazy var urlOpener: UrlOpener = {
        return self.injector!.create(UrlOpener.self) as! UrlOpener
    }()

    private lazy var quickActionRepository: QuickActionRepository = {
        return self.injector!.create(QuickActionRepository.self) as! QuickActionRepository
    }()

    private var oldTheme: ThemeRepository.Theme = .Default

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

    public override func canBecomeFirstResponder() -> Bool {
        return true
    }

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

    internal func didHitChangeTheme(keyCommand: UIKeyCommand) {

    }

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
}

extension SettingsViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
        self.view.backgroundColor = self.themeRepository.backgroundColor
        // swiftlint:disable line_length
        self.tableView.backgroundColor = self.themeRepository.theme == .Default ? nil : self.themeRepository.backgroundColor
        for section in 0..<self.tableView.numberOfSections {
            let headerView = self.tableView.headerViewForSection(section)
            headerView?.textLabel?.textColor = self.themeRepository.theme == .Default ? nil : self.themeRepository.tintColor
        }
        // swiftlint:enable line_length
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 3
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        guard let section = SettingsSection(rawValue: sectionNum) else {
            return 0
        }
        switch section {
        case .Theme:
            return 2
        case .Advanced:
            return 1
        case .Credits:
            return 1
        }
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let section = SettingsSection(rawValue: indexPath.section) else {
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
            cell.detailTextLabel?.text = NSLocalizedString("SettingsViewController_Credits_MainDeveloper_Detail", comment: "")
            return cell
        }
    }

    public func tableView(tableView: UITableView, titleForHeaderInSection sectionNum: Int) -> String? {
        guard let section = SettingsSection(rawValue: sectionNum) else {
            return nil
        }
        return section.description
    }
}

extension SettingsViewController: UITableViewDelegate {
    public func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return
        }

        if section == .Theme {
            tableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: .None)
        }
    }

    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return
        }
        switch section {
        case .Theme:
            guard let theme = ThemeRepository.Theme(rawValue: indexPath.row) else {
                return
            }
            self.themeRepository.theme = theme
            self.navigationItem.rightBarButtonItem?.enabled = true
        case .Advanced:
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            if let documentation = injector?.create(DocumentationViewController.self) as? DocumentationViewController {
                documentation.configure(.QueryFeed)
                self.navigationController?.pushViewController(documentation, animated: true)
            }
            return
        case .Credits:
            tableView.deselectRowAtIndexPath(indexPath, animated: false)
            guard let url = NSURL(string: "https://twitter.com/younata") else {
                return
            }
            if #available(iOS 9.0, *) {
                let viewController = SFSafariViewController(URL: url)
                self.navigationController?.pushViewController(viewController, animated: true)
            } else {
                self.urlOpener.openURL(url)
            }
            return
        }
        self.tableView.reloadData()
        self.tableView.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: .None)
    }
}

import UIKit
import PureLayout_iOS

public class SettingsViewController: UIViewController {
    private enum SettingsSection: Int, CustomStringConvertible {
        case Theme = 0
        case Advanced = 1

        private var description: String {
            switch self {
            case .Theme:
                return NSLocalizedString("Theme", comment: "")
            case .Advanced:
                return NSLocalizedString("Advanced", comment: "")
            }
        }
    }

    public lazy var userDefaults = NSUserDefaults.standardUserDefaults()

    public let tableView = UITableView(frame: CGRectZero, style: .Grouped)

    private lazy var actualThemeRepository: ThemeRepository = {
        return self.injector!.create(ThemeRepository.self) as! ThemeRepository
    }()

    private lazy var settingsRepository: SettingsRepository = {
        return self.injector!.create(SettingsRepository.self) as! SettingsRepository
    }()

    private lazy var queryFeedsEnabled: Bool = {
        return self.settingsRepository.queryFeedsEnabled
    }()

    private var ephemeralThemeRepository: ThemeRepository? = nil {
        didSet {
            if self.ephemeralThemeRepository == nil {
                self.didChangeTheme()
            }
        }
    }

    private var themeRepository: ThemeRepository {
        return self.ephemeralThemeRepository ?? self.actualThemeRepository
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("Settings", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: "didTapSave")
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "didTapDismiss")

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.tableView.registerClass(TableViewCell.self, forCellReuseIdentifier: "cell")
        self.tableView.registerClass(SwitchTableViewCell.self, forCellReuseIdentifier: "switch")
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.allowsMultipleSelection = true

        self.themeRepository.addSubscriber(self)

        let selectedIndexPath = NSIndexPath(forRow: self.themeRepository.theme.rawValue, inSection: SettingsSection.Theme.rawValue)
        self.tableView.selectRowAtIndexPath(selectedIndexPath, animated: false, scrollPosition: .None)
    }

    internal func didTapDismiss() {
        self.navigationController?.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    internal func didTapSave() {
        self.didTapDismiss()
        if let themeRepository = self.ephemeralThemeRepository {
            self.actualThemeRepository.theme = themeRepository.theme
        }
        self.settingsRepository.queryFeedsEnabled = self.queryFeedsEnabled
    }
}

extension SettingsViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
        self.view.backgroundColor = self.themeRepository.backgroundColor
        self.tableView.backgroundColor = self.themeRepository.theme == .Default ? nil : self.themeRepository.backgroundColor
        for section in 0..<self.tableView.numberOfSections {
            let headerView = self.tableView.headerViewForSection(section)
            headerView?.textLabel?.textColor = self.themeRepository.theme == .Default ? nil : self.themeRepository.tintColor
        }
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection sectionNum: Int) -> Int {
        guard let section = SettingsSection(rawValue: sectionNum) else {
            return 0
        }
        switch (section) {
        case .Theme:
            return 2
        case .Advanced:
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
            let cell = tableView.dequeueReusableCellWithIdentifier("switch", forIndexPath: indexPath) as! SwitchTableViewCell
            cell.textLabel?.text = NSLocalizedString("Enable Query Feeds", comment: "")
            cell.themeRepository = self.themeRepository
            cell.onTapSwitch = {_ in }
            cell.theSwitch.on = self.queryFeedsEnabled
            cell.onTapSwitch = {aSwitch in
                self.queryFeedsEnabled = aSwitch.on
                self.navigationItem.rightBarButtonItem?.enabled = true
            }
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
    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return
        }
        switch section {
        case .Theme:
            guard let theme = ThemeRepository.Theme(rawValue: indexPath.row) else {
                return
            }
            self.ephemeralThemeRepository = ThemeRepository(userDefaults: nil)
            self.ephemeralThemeRepository?.theme = theme
            self.ephemeralThemeRepository?.addSubscriber(self)
            self.navigationItem.rightBarButtonItem?.enabled = true
        case .Advanced:
            return
        }
        self.tableView.reloadData()
    }
}

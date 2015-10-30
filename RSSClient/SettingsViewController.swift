import UIKit
import PureLayout_iOS

public class SettingsViewController: UIViewController {
    private enum SettingsSection: Int, CustomStringConvertible {
        case Theme = 0

        private var description: String {
            switch self {
            case .Theme:
                return NSLocalizedString("Theme", comment: "")
            }
        }
    }

    public lazy var userDefaults = NSUserDefaults.standardUserDefaults()

    public let tableView = UITableView(frame: CGRectZero, style: .Grouped)

    private lazy var actualThemeRepository: ThemeRepository = {
        return self.injector!.create(ThemeRepository.self) as! ThemeRepository
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
    }
}

extension SettingsViewController: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.navigationController?.navigationBar.barStyle = self.themeRepository.barStyle
        self.view.backgroundColor = self.themeRepository.backgroundColor
        self.tableView.backgroundColor = self.themeRepository.theme == .Default ? nil : self.themeRepository.backgroundColor
        for section in 0..<self.tableView.numberOfSections {
            let headerView = self.tableView.headerViewForSection(section)
            headerView?.tintColor = self.themeRepository.theme == .Default ? nil : self.themeRepository.tintColor
            headerView?.textLabel?.textColor = self.themeRepository.theme == .Default ? nil : self.themeRepository.textColor
        }
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
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
        }
        self.tableView.reloadData()
    }
}

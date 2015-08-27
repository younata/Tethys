import UIKit
import PureLayout_iOS

public let kNightModeEnabled = "nightMode"

public class SettingsViewController: UIViewController {
    public private(set) lazy var enableNightModeSwitch: UISwitch = {
        let theSwitch = UISwitch(forAutoLayout: ())
        theSwitch.on = self.userDefaults.boolForKey(kNightModeEnabled)
        theSwitch.addTarget(self, action: "didChangeNightMode", forControlEvents: .ValueChanged)
        return theSwitch
    }()

    public lazy var userDefaults = NSUserDefaults.standardUserDefaults()

    public let tableView = UITableView(frame: CGRectZero, style: .Grouped)

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("Settings", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: "didTapSave")
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "didTapDismiss")

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)

        self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "nightMode")
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    internal func didTapDismiss() {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    internal func didTapSave() {
        self.userDefaults.setBool(self.enableNightModeSwitch.on, forKey: kNightModeEnabled)

        self.didTapDismiss()
    }

    internal func didChangeNightMode() {
        self.navigationItem.rightBarButtonItem?.enabled = true
    }

    private func changeTextColors() {
        UILabel.appearance().textColor = self.enableNightModeSwitch.on ? UIColor.blueColor() : UIColor.blackColor()
        self.view.layoutSubviews()
    }

    enum SettingsSection: Int, CustomStringConvertible {
        case NightMode = 0

        var description: String {
            switch self {
            case .NightMode:
                return NSLocalizedString("Night Mode", comment: "")
            }
        }
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let section = SettingsSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        switch section {
        case .NightMode:
            let cell = tableView.dequeueReusableCellWithIdentifier("nightMode", forIndexPath: indexPath)
            cell.textLabel?.text = NSLocalizedString("Enabled", comment: "")
            cell.accessoryView = self.enableNightModeSwitch
            cell.selectionStyle = .None
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

}

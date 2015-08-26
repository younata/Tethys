import UIKit
import PureLayout_iOS

public class SettingsViewController: UIViewController {
    public private(set) lazy var enableNightModeSwitch: UISwitch = {
        let theSwitch = UISwitch(forAutoLayout: ())
        theSwitch.addTarget(self, action: "didChangeNightMode", forControlEvents: .ValueChanged)
        return theSwitch
    }()

    public lazy var userDefaults = NSUserDefaults.standardUserDefaults()

    public let tableView = UITableView(forAutoLayout: ())

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = NSLocalizedString("Settings", comment: "")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Save, target: self, action: "didTapSave")
        self.navigationItem.rightBarButtonItem?.enabled = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "didTapDismiss")

        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
    }

    internal func didTapDismiss() {
        self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
    }

    internal func didTapSave() {
        self.userDefaults.setBool(self.enableNightModeSwitch.on, forKey: "nightMode")
        self.didTapDismiss()
    }

    internal func didChangeNightMode() {
        self.navigationItem.rightBarButtonItem?.enabled = true
    }
}

extension SettingsViewController: UITableViewDataSource {
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
}

extension SettingsViewController: UITableViewDelegate {

}

import UIKit

public class SplitDelegate: NSObject, UISplitViewControllerDelegate {
    public var collapseDetailViewController: Bool = true {
        didSet {
        }
    }

    private let splitController: UISplitViewController

    public init(splitViewController: UISplitViewController) {
        self.splitController = splitViewController
    }

    public func splitViewController(splitViewController: UISplitViewController,
        collapseSecondaryViewController secondaryViewController: UIViewController,
        ontoPrimaryViewController primaryViewController: UIViewController) -> Bool {
            return collapseDetailViewController
    }
}

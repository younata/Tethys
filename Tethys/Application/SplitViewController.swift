import UIKit
import SafariServices

public final class SplitViewController: UISplitViewController {
    public var collapseDetailViewController: Bool = true

    public private(set) lazy var masterNavigationController: UINavigationController = {
        return UINavigationController()
    }()

    public private(set) var detailNavigationController: UINavigationController = {
        return UINavigationController()
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self
        self.preferredDisplayMode = .allVisible
    }
}

extension SplitViewController: UISplitViewControllerDelegate {
    public func splitViewController(_ splitViewController: UISplitViewController,
                                    collapseSecondary secondaryViewController: UIViewController,
                                    onto primaryViewController: UIViewController) -> Bool {
        return self.collapseDetailViewController
    }
}

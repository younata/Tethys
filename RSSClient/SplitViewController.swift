import UIKit
import SafariServices

public class SplitViewController: UISplitViewController {
    public var collapseDetailViewController: Bool = true

    public private(set) lazy var masterNavigationController: UINavigationController = {
        return UINavigationController()
    }()

    public private(set) var detailNavigationController: UINavigationController = {
        return UINavigationController()
    }()

    private lazy var themeRepository: ThemeRepository? = {
        return self.injector?.create(ThemeRepository)
    }()

    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        if #available(iOS 9, *) {
            for vc in self.viewControllers {
                if vc is SFSafariViewController {
                    return .Default
                } else if let nc = vc as? UINavigationController {
                    if nc.visibleViewController is SFSafariViewController {
                        return .Default
                    }
                }
            }
        }
        return self.themeRepository?.statusBarStyle ?? super.preferredStatusBarStyle()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.themeRepository?.addSubscriber(self)
        self.delegate = self
        self.preferredDisplayMode = .PrimaryOverlay
    }
}

extension SplitViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.setNeedsStatusBarAppearanceUpdate()
    }
}

extension SplitViewController: UISplitViewControllerDelegate {
    public func splitViewController(splitViewController: UISplitViewController,
        collapseSecondaryViewController secondaryViewController: UIViewController,
        ontoPrimaryViewController primaryViewController: UIViewController) -> Bool {
            return self.collapseDetailViewController
    }

    // swiftlint:disable line_length
    public func primaryViewControllerForCollapsingSplitViewController(splitViewController: UISplitViewController) -> UIViewController? {
        return self.viewControllers.first
    }

    public func targetDisplayModeForActionInSplitViewController(svc: UISplitViewController) -> UISplitViewControllerDisplayMode {
        return .AllVisible
    }
    // swiftlint:enable line_length
}

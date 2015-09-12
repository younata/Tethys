import UIKit

public class SplitViewController: UISplitViewController {
    public var collapseDetailViewController: Bool = true

    private lazy var themeRepository: ThemeRepository? = {
        return self.injector?.create(ThemeRepository.self) as? ThemeRepository
    }()

    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
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
    public func didChangeTheme() {
        self.setNeedsStatusBarAppearanceUpdate()
    }
}

extension SplitViewController: UISplitViewControllerDelegate {
    public func splitViewController(splitViewController: UISplitViewController,
        collapseSecondaryViewController secondaryViewController: UIViewController,
        ontoPrimaryViewController primaryViewController: UIViewController) -> Bool {
            return self.collapseDetailViewController
    }

    public func primaryViewControllerForCollapsingSplitViewController(splitViewController: UISplitViewController) -> UIViewController? {
        return self.viewControllers.first
    }

    public func targetDisplayModeForActionInSplitViewController(svc: UISplitViewController) -> UISplitViewControllerDisplayMode {
        return .AllVisible
    }
}

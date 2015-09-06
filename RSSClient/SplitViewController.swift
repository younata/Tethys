import UIKit

public class SplitViewController: UISplitViewController {
    public var collapseDetailViewController: Bool = true

    public override var delegate: UISplitViewControllerDelegate? {
        get {
            return self
        }
        set {}
    }

    public lazy var themeRepository: ThemeRepository? = {
        return self.injector?.create(ThemeRepository.self) as? ThemeRepository
    }()

    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return self.themeRepository?.theme == .Dark ? .LightContent : super.preferredStatusBarStyle()
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
}

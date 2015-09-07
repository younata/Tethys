import UIKit

public class SplitViewController: UISplitViewController {
    public var collapseDetailViewController: Bool = true

    private lazy var themeRepository: ThemeRepository? = {
        return self.injector?.create(ThemeRepository.self) as? ThemeRepository
    }()

    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return self.themeRepository?.theme == .Dark ? .LightContent : super.preferredStatusBarStyle()
    }

    public init() {
        super.init(nibName: nil, bundle: nil)

        self.delegate = self
        self.preferredDisplayMode = .PrimaryOverlay
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError()
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

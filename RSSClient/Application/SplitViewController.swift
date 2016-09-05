import UIKit
import SafariServices
import Ra

public final class SplitViewController: UISplitViewController, Injectable {
    public var collapseDetailViewController: Bool = true

    public private(set) lazy var masterNavigationController: UINavigationController = {
        return UINavigationController()
    }()

    public private(set) var detailNavigationController: UINavigationController = {
        return UINavigationController()
    }()

    private let themeRepository: ThemeRepository

    public init(themeRepository: ThemeRepository) {
        self.themeRepository = themeRepository
        super.init(nibName: nil, bundle: nil)
    }

    public required convenience init(injector: Injector) {
        self.init(themeRepository: injector.create(ThemeRepository)!)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func preferredStatusBarStyle() -> UIStatusBarStyle {
        for vc in self.viewControllers {
            if vc is SFSafariViewController {
                return .default
            } else if let nc = vc as? UINavigationController {
                if nc.visibleViewController is SFSafariViewController {
                    return .default
                }
            }
        }
        return self.themeRepository.statusBarStyle ?? super.preferredStatusBarStyle
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.themeRepository.addSubscriber(self)
        self.delegate = self
        self.preferredDisplayMode = .allVisible
    }
}

extension SplitViewController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.setNeedsStatusBarAppearanceUpdate()
    }
}

extension SplitViewController: UISplitViewControllerDelegate {
    public func splitViewController(_ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController) -> Bool {
            return self.collapseDetailViewController
    }
}

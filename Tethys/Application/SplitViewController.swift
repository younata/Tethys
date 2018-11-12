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

    private let themeRepository: ThemeRepository

    public init(themeRepository: ThemeRepository) {
        self.themeRepository = themeRepository
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        for vc in self.viewControllers {
            if vc is SFSafariViewController {
                return .default
            } else if let nc = vc as? UINavigationController {
                if nc.visibleViewController is SFSafariViewController {
                    return .default
                }
            }
        }
        return self.themeRepository.statusBarStyle
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

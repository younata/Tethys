import UIKit

public final class BlankViewController: UIViewController, ThemeRepositorySubscriber {
    private let themeRepository: ThemeRepository

    public init(themeRepository: ThemeRepository) {
        self.themeRepository = themeRepository

        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        self.themeRepository.addSubscriber(self)
    }

    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.view.backgroundColor = themeRepository.theme.backgroundColor
        self.navigationController?.navigationBar.barStyle = themeRepository.theme.barStyle
    }
}

import SpriteKit

final class RogueLikeViewController: UIViewController {
    let sceneView = SKView()
    let game: RogueLikeGame

    let exitButton = UIButton(type: .system)

    init() {
        self.game = RogueLikeGame(view: self.sceneView, levelGenerator: BoxLevelGenerator())
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.overrideUserInterfaceStyle = .dark

        self.sceneView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.sceneView)
        self.sceneView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .top)

        let menuView = UIView(forAutoLayout: ())
        menuView.backgroundColor = Theme.overlappingBackgroundColor
        self.view.addSubview(menuView)
        menuView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        self.sceneView.autoPinEdge(.top, to: .bottom, of: menuView)
        self.configureExitButton()

        menuView.addSubview(self.exitButton)
        self.exitButton.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        self.exitButton.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        self.exitButton.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)

        self.game.start(bounds: self.view.bounds.inset(by: self.view.safeAreaInsets))

        let dpadGestureRecognizer = DirectionalGestureRecognizer(
            target: self,
            action: #selector(RogueLikeViewController.didRecognize(directionGestureRecognizer:))
        )
        self.sceneView.addGestureRecognizer(dpadGestureRecognizer)
    }

    private func configureExitButton() {
        self.exitButton.addTarget(self, action: #selector(exit), for: .touchUpInside)
        self.exitButton.setTitle(NSLocalizedString("Generic_Close", comment: ""), for: .normal)
        self.exitButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.exitButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        self.exitButton.setTitleColor(Theme.highlightColor, for: .normal)
        self.exitButton.isAccessibilityElement = true
        self.exitButton.accessibilityTraits = [.button]
        self.exitButton.accessibilityLabel = NSLocalizedString("Generic_Close", comment: "")
    }

    @objc private func exit() {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc private func didRecognize(directionGestureRecognizer: DirectionalGestureRecognizer) {
        self.game.guidePlayer(direction: directionGestureRecognizer.direction)
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(
            x: self.origin.x + (self.size.width / 2),
            y: self.origin.y + (self.size.height / 2)
        )
    }
}

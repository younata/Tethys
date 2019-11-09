import SpriteKit

final class RogueLikeViewController: UIViewController {
    let sceneView = SKView()
    let game: RogueLikeGame

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
        self.sceneView.autoPinEdgesToSuperviewSafeArea(with: .zero)

        self.game.start(bounds: self.view.bounds.inset(by: self.view.safeAreaInsets))

        let dpadGestureRecognizer = DirectionalGestureRecognizer(
            target: self,
            action: #selector(RogueLikeViewController.didRecognize(directionGestureRecognizer:))
        )
        self.view.addGestureRecognizer(dpadGestureRecognizer)
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

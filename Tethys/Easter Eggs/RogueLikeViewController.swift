import SpriteKit

final class RogueLikeViewController: UIViewController {
    let sceneView = SKView()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.overrideUserInterfaceStyle = .dark

        self.sceneView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.sceneView)
        self.sceneView.autoPinEdgesToSuperviewEdges(with: .zero)

        let scene = SKScene()
        scene.physicsWorld.gravity = .zero
        scene.backgroundColor = Theme.backgroundColor
        self.sceneView.presentScene(scene)
    }
}

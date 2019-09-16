import ARKit
import PureLayout

public final class AugmentedRealityEasterEggViewController: UIViewController {
    private let feedListControllerFactory: () -> FeedListController

    private let arView = ARSCNView()

    private var shownControllers: [SCNNode: UIViewController] = [:]

    public init(feedListControllerFactory: @escaping () -> FeedListController) {
        self.feedListControllerFactory = feedListControllerFactory
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.arView)
        self.arView.autoPinEdgesToSuperviewEdges()
        self.configureARView()

        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self, action: #selector(AugmentedRealityEasterEggViewController.didTapView(gestureRecognizer:))
        )
        self.arView.addGestureRecognizer(tapGestureRecognizer)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.arView.session.pause()
    }

    private func configureARView() {
        self.arView.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        self.arView.session.run(configuration)
    }

    @objc private func didTapView(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended else { return }

        guard let location = self.arView.hitTest(gestureRecognizer.location(in: self.arView),
                                                 types: .featurePoint).first?.worldTransform else {
                                                    return
        }

        self.insertAppInstance(at: location)
    }

    private func insertAppInstance(at transform: simd_float4x4) {
        let feedListController = self.feedListControllerFactory()
        let plane = SCNPlane(width: 450, height: 800)
        let navController = UINavigationController(rootViewController: feedListController)
        navController.view.bounds = CGRect(x: 0, y: 0, width: 450, height: 800)
        plane.firstMaterial = SCNMaterial()
        plane.firstMaterial?.diffuse.contents = navController.view
        let node = SCNNode(geometry: plane)
        node.simdWorldTransform = transform
        self.shownControllers[node] = navController
    }
}

extension AugmentedRealityEasterEggViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.arView.hitTest(gestureRecognizer.location(in: self.arView), options: nil).isEmpty
    }
}

extension AugmentedRealityEasterEggViewController: ARSCNViewDelegate {
    public func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        self.shownControllers.removeValue(forKey: node)
    }
}

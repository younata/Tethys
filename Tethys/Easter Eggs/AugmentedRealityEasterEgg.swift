import ARKit
import PureLayout

private class ARViewLabel: UIView {
    let label = UILabel(forAutoLayout: ())

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.tertiarySystemFill
        self.label.textColor = UIColor.label

        self.label.numberOfLines = 0
        self.label.font = UIFont.preferredFont(forTextStyle: .body)

        self.layer.cornerRadius = 4
        self.addSubview(self.label)
        self.label.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(text: String) {
        self.label.text = text
        self.isHidden = false
    }

    func hide() {
        self.isHidden = true
    }
}

public final class AugmentedRealityEasterEggViewController: UIViewController {
    private let feedListControllerFactory: () -> FeedListController

    private let arView = ARSCNView()

    private let explanationView = ARViewLabel(frame: .zero)
    private let exitButton = UIButton(forAutoLayout: ())

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

        self.view.addSubview(self.explanationView)
        self.explanationView.autoAlignAxis(toSuperviewAxis: .vertical)
        self.explanationView.autoPinEdge(toSuperviewEdge: .top, withInset: 20)
        self.explanationView.hide()

        self.view.addSubview(self.exitButton)
        self.exitButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: 20)
        self.exitButton.autoPinEdge(.top, to: .top, of: self.explanationView)
        self.exitButton.autoPinEdge(.leading, to: .trailing, of: self.explanationView, withOffset: 8)

        self.exitButton.layer.cornerRadius = 4
        self.exitButton.setTitle(NSLocalizedString("Generic_Close", comment: ""), for: .normal)
        self.exitButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.exitButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        self.exitButton.backgroundColor = UIColor.tertiarySystemFill
        self.exitButton.setTitleColor(UIColor.label, for: .normal)
        self.exitButton.addTarget(self, action: #selector(exit), for: .touchUpInside)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.arView.session.pause()
    }

    private func configureARView() {
        self.arView.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        self.arView.session.run(configuration)

        self.arView.showsStatistics = true
    }

    @objc private func exit() {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc private func didTapView(gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended else { return }
        guard let camera = self.arView.session.currentFrame?.camera else { return }

        var translation = matrix_identity_float4x4
        translation.columns.3.z = -1

        let rotation = matrix_float4x4(SCNMatrix4MakeRotation(Float.pi/2, 0, 0, 1))

        let anchorTransform = matrix_multiply(camera.transform, matrix_multiply(translation, rotation))

        self.insertAppInstance(at: anchorTransform)
    }

    private func insertAppInstance(at transform: simd_float4x4) {
        let feedListController = self.feedListControllerFactory()
        let bounds = UIScreen.main.bounds
        let plane = SCNPlane(width: bounds.size.width / 1000, height: bounds.size.height / 1000)
        let navController = UINavigationController(rootViewController: feedListController)
        navController.view.bounds = bounds
        plane.firstMaterial = SCNMaterial()
        plane.firstMaterial?.isDoubleSided = true
        plane.firstMaterial?.diffuse.contents = navController.view
        let node = SCNNode(geometry: plane)
        node.simdTransform = transform
        self.shownControllers[node] = navController
        self.arView.scene.rootNode.addChildNode(node)
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

    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            self.arView.debugOptions = []
            self.explanationView.hide()
        case .notAvailable:
            self.arView.debugOptions = .showFeaturePoints
            self.explanationView.show(text: NSLocalizedString("AREasterEgg_Tracking_NotAvailable", comment: ""))
        case .limited(let reason):
            self.arView.debugOptions = .showFeaturePoints
            let message: String
            switch reason {
            case .excessiveMotion:
                message = NSLocalizedString("AREasterEgg_Tracking_ExcessiveMotion", comment: "")
            case .initializing:
                message = NSLocalizedString("AREasterEgg_Tracking_Initializing", comment: "")
            case .insufficientFeatures:
                message = NSLocalizedString("AREasterEgg_Tracking_InsufficientFeatures", comment: "")
            case .relocalizing:
                message = NSLocalizedString("AREasterEgg_Tracking_Relocalizing", comment: "")
            default:
                message = String.localizedStringWithFormat(
                    NSLocalizedString("AREasterEgg_Tracking_Unknown", comment: ""),
                    "\(reason)"
                )
            }
            self.explanationView.show(text: message)

        }
    }
}

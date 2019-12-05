import SpriteKit

final class RogueLikeGame: NSObject {
    let player: SKNode = {
        var path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -10, y: -10, width: 20, height: 20))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0, y: 10))
        path.addLine(to: CGPoint(x: 5, y: -9))
        path.addLine(to: CGPoint(x: -5, y: -9))
        path.closeSubpath()
        let node = SKShapeNode(path: path, centered: true)
        node.fillColor = Theme.highlightColor
        node.strokeColor = .white
        node.physicsBody = SKPhysicsBody(polygonFrom: CGPath(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20),
                                                             transform: nil))
        node.physicsBody?.allowsRotation = false
        node.physicsBody?.restitution = 0
        node.physicsBody?.friction = 1.0
        return node
    }()
    let view: SKView
    let levelGenerator: LevelGenerator

    init(view: SKView, levelGenerator: LevelGenerator) {
        self.view = view
        self.levelGenerator = levelGenerator

        super.init()
    }

    func start(bounds: CGRect) {
        self.view.presentScene(self.levelScene(bounds: bounds, safeArea: self.view.safeAreaInsets))

        self.player.position = bounds.center
        self.view.scene?.addChild(self.player)
    }

    func levelScene(bounds: CGRect, safeArea: UIEdgeInsets) -> SKScene {
        let scene = SKScene(size: bounds.size)
        scene.physicsWorld.gravity = .zero

        let level = self.levelGenerator.generate(level: 1, bounds: bounds.inset(by: safeArea))
        scene.addChild(level.node)
        scene.isPaused = false

        return scene
    }

    func guidePlayer(direction: CGVector) {
        let unitsPerSecond: CGFloat = 50
        self.player.physicsBody?.velocity = CGVector(
            dx: direction.dx * unitsPerSecond,
            dy: direction.dy * -unitsPerSecond
        )
        guard direction != .zero else { return }
        self.player.zRotation = atan2(-direction.dy, direction.dx) - (.pi / 2)
    }
}

struct Level {
    let number: Int
    let node: SKNode
}

protocol LevelGenerator {
    func generate(level number: Int, bounds: CGRect) -> Level
}

struct BoxLevelGenerator: LevelGenerator {
    func generate(level number: Int, bounds: CGRect) -> Level {
        let roomRect = bounds.inset(by: UIEdgeInsets(top: 24, left: 0, bottom: 8, right: 0))
        let room = SKShapeNode(rect: roomRect)
        room.fillColor = .clear
        room.strokeColor = .white
        room.lineWidth = 2
        room.physicsBody = SKPhysicsBody(edgeLoopFrom: roomRect)
        room.physicsBody?.isDynamic = false
        room.physicsBody?.restitution = 0
        room.physicsBody?.friction = 1.0

        return Level(number: number, node: room)
    }
}

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
        node.physicsBody = SKPhysicsBody(circleOfRadius: 20)
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
        self.view.presentScene(self.levelScene(bounds: bounds))

        self.player.position = bounds.center
        self.view.scene?.addChild(self.player)
    }

    func levelScene(bounds: CGRect) -> SKScene {
        let scene = SKScene(size: bounds.size)
        scene.physicsWorld.gravity = .zero

        let level = self.levelGenerator.generate(level: 1, bounds: bounds)
        scene.addChild(level.node)

        return scene
    }

    func guidePlayer(direction: CGVector) {
        self.player.physicsBody?.velocity = direction
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
        let room = SKShapeNode(rect: bounds.insetBy(dx: 20, dy: 20))
        room.fillColor = .clear
        room.strokeColor = .white
        room.lineWidth = 2

        return Level(number: number, node: room)
    }
}

import Quick
import Nimble
import SpriteKit

@testable import Tethys

final class RogueLikeGameSpec: QuickSpec {
    override func spec() {
        var subject: RogueLikeGame!

        var view: SKView!
        var levelGenerator: FakeLevelGenerator!

        beforeEach {
            view = SKView()
            levelGenerator = FakeLevelGenerator()

            subject = RogueLikeGame(view: view, levelGenerator: levelGenerator)
        }

        describe("-start(bounds:)") {
            let bounds = CGRect(x: 0, y: 0, width: 320, height: 480)

            let level = Level(number: 0, node: SKNode())

            beforeEach {
                levelGenerator.level = level
                subject.start(bounds: bounds)
            }

            it("sets the view's scene") {
                guard let scene = view.scene else {
                    return expect(view.scene).toNot(beNil())
                }
                expect(scene.children).to(haveCount(2))
                expect(scene.children).to(contain(level.node))
                expect(scene.children).to(contain(subject.player))

                expect(levelGenerator.generateCalls).to(haveCount(1))
                expect(levelGenerator.generateCalls.last?.number).to(equal(1))
                expect(levelGenerator.generateCalls.last?.bounds).to(equal(bounds))
            }

            it("configures the player") {
                expect(subject.player).to(beAKindOf(SKShapeNode.self))
                guard let player = subject.player as? SKShapeNode else {
                    return
                }
                expect(player.physicsBody).toNot(beNil())
            }
        }
    }
}

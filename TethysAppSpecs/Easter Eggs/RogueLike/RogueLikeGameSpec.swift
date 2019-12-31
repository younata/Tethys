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
                expect(scene.children).to(haveCount(3))
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
                expect(player.physicsBody?.allowsRotation).to(beFalse())
                expect(player.physicsBody?.restitution).to(equal(0))
                expect(player.physicsBody?.friction).to(equal(1.0))
            }

            describe("moving the player") {
                beforeEach {
                    subject.guidePlayer(direction: CGVector(dx: sin(45.rads), dy: sin(45.rads)))
                }

                it("reverses the dy and multiplies both dx and dy by 50") {
                    let dx = sin(45.rads) * 50
                    let dy = sin(45.rads) * -50
                    expect(subject.player.physicsBody?.velocity.dx).to(beCloseTo(dx))
                    expect(subject.player.physicsBody?.velocity.dy).to(beCloseTo(dy))
                }

                it("rotates the user to face where the user is guiding them") {
                    expect(subject.player.zRotation.degrees).to(beCloseTo(-135))
                }

                describe("telling the player to stop moving") {
                    beforeEach {
                        subject.guidePlayer(direction: .zero)
                    }

                    it("stops the player's movements") {
                        expect(subject.player.physicsBody?.velocity).to(equal(.zero))
                    }

                    it("keeps the rotation of the player") {
                        expect(subject.player.zRotation.degrees).to(beCloseTo(-135))
                    }
                }
            }
        }
    }
}

private extension CGFloat {
    var degrees: CGFloat {
        return self * 180 / .pi
    }
}

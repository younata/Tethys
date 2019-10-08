import Quick
import Nimble
import SceneKit
@testable import Tethys

final class Breakout3DSpec: QuickSpec {
    override func spec() {
        var subject: Breakout3DEasterEggViewController!
        var mainQueue: FakeOperationQueue!

        beforeEach {
            mainQueue = FakeOperationQueue()

            mainQueue.runSynchronously = true

            subject = Breakout3DEasterEggViewController(mainQueue: mainQueue)
            subject.view.bounds = CGRect(x: 0, y: 0, width: 320, height: 480)

            subject.viewDidAppear(false)
        }

        it("starts the breakout game") {
            expect(subject.breakoutGame).toNot(beNil())
            expect(subject.breakoutGame?.scene.isPaused).to(beFalse())
        }

        it("shows the score") {
            expect(subject.scoreLabel.text).to(equal("0 points"))
        }

        describe("the physicsWorld's contactDelegate") {
            var delegate: SCNPhysicsContactDelegate?
            var ball: SCNNode?

            var contact: SCNPhysicsContact!

            beforeEach {
                ball = subject.breakoutGame?.scene.rootNode.childNode(withName: subject.breakoutGame!.ballNodeName, recursively: true)
                expect(ball).toNot(beNil())
                delegate = subject.breakoutGame?.scene.physicsWorld.contactDelegate
            }

            describe("when the ball hits a wall") {
                var sideWall: SCNNode?
                beforeEach {
                    contact = SCNPhysicsContact()
                    contact.setValue(ball, forKey: "nodeA")

                    sideWall = subject.breakoutGame?.scene.rootNode.childNodes { (node, stop) -> Bool in
                        guard let physicsBitMask = node.physicsBody?.categoryBitMask else {
                            return false
                        }
                        let wallCategory = subject.breakoutGame!.wallCategory
                        let rearWallCategory = subject.breakoutGame!.rearWallCategory
                        guard (physicsBitMask & rearWallCategory) == 0 else {
                            return false
                        }
                        if (physicsBitMask & wallCategory) != 0 {
                            stop.assign(repeating: true, count: 1)
                            return true
                        }
                        return false
                    }.first
                    guard let wall = sideWall else {
                        return expect(sideWall).toNot(beNil())
                    }
                    contact.setValue(wall, forKey: "nodeB")

                    delegate?.physicsWorld?(subject.breakoutGame!.scene.physicsWorld, didEnd: contact)
                }

                it("keeps the side wall in the game") {
                    expect(sideWall?.parent).toNot(beNil())
                }

                it("keeps the ball in the game") {
                    expect(ball?.parent).toNot(beNil())
                }

                // it triggers an impact event.
            }

            describe("when the ball hits a brick") {
                var brick: SCNNode?
                beforeEach {
                    contact = SCNPhysicsContact()
                    contact.setValue(ball, forKey: "nodeB")

                    brick = subject.breakoutGame?.scene.rootNode.childNodes { (node, stop) -> Bool in
                        if node.physicsBody?.categoryBitMask == subject.breakoutGame!.brickCategory {
                            stop.assign(repeating: true, count: 1)
                            return true
                        }
                        return false
                    }.first
                    expect(brick).toNot(beNil())
                    contact.setValue(brick!, forKey: "nodeA")

                    delegate?.physicsWorld?(subject.breakoutGame!.scene.physicsWorld, didEnd: contact)
                }

                it("removes the brick from the game") {
                    expect(brick?.parent).to(beNil())
                }

                it("keeps the ball in the game") {
                    expect(ball?.parent).toNot(beNil())
                }

                it("updates the score") {
                    expect(subject.scoreLabel.text).to(equal("1 point"))
                }

                // it triggers an impact event.
            }

            describe("when the ball hits the rear wall") {
                // it resets the game

                // it triggers an impact event.
            }

            describe("when the ball hits the paddle") {
                var paddle: SCNNode?

                beforeEach {
                    contact = SCNPhysicsContact()
                    contact.setValue(ball, forKey: "nodeA")

                    paddle = subject.breakoutGame?.scene.rootNode.childNode(withName: subject.breakoutGame!.paddleNodeName, recursively: true)
                    expect(paddle).toNot(beNil())
                    contact.setValue(paddle!, forKey: "nodeB")

                    delegate?.physicsWorld?(subject.breakoutGame!.scene.physicsWorld, didEnd: contact)
                }

                it("keeps the paddle in the game") {
                    expect(paddle?.parent).toNot(beNil())
                }

                it("keeps the ball in the game") {
                    expect(ball?.parent).toNot(beNil())
                }

                // it triggers an impact event
            }
        }
    }
}

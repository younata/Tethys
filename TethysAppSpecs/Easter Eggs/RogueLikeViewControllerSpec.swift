import Quick
import Nimble
import SceneKit
@testable import Tethys

final class RogueLikeViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: RogueLikeViewController!

        beforeEach {
            subject = RogueLikeViewController()

            subject.view.bounds = CGRect(x: 0, y: 0, width: 320, height: 480)

            subject.viewDidAppear(false)
        }

        it("shows a spritekit scene") {
            let scene = subject.sceneView.scene
            expect(scene?.physicsWorld.gravity).to(equal(CGVector.zero))
        }

        it("configures the view for landscape") {
            expect(subject.supportedInterfaceOrientations).to(equal([.landscape]))
        }

        describe("the exit button") {
            it("is configured for accessibility") {
                expect(subject.exitButton.isAccessibilityElement).to(beTrue())
                expect(subject.exitButton.accessibilityTraits).to(equal([.button]))
                expect(subject.exitButton.accessibilityLabel).to(equal("Close"))
            }

            it("is styled like a nav button elsewhere in the app") {
                expect(subject.exitButton.titleColor(for: .normal)).to(equal(Theme.highlightColor))
            }

            it("dismisses itself when tapped") {
                let presentingController = UIViewController()
                presentingController.present(subject, animated: false, completion: nil)
                expect(subject.presentingViewController).to(be(presentingController))
                expect(presentingController.presentedViewController).to(be(subject))

                subject.exitButton.sendActions(for: .touchUpInside)
                expect(presentingController.presentedViewController).to(beNil())
            }
        }

        describe("when the directional gesture recognizer updates") {
            var gestureRecognizer: DirectionalGestureRecognizer?
            var observer: GestureObserver!

            beforeEach {
                gestureRecognizer = subject.sceneView.gestureRecognizers?.compactMap { $0 as? DirectionalGestureRecognizer }.first
                expect(gestureRecognizer).toNot(beNil())
                observer = gestureRecognizer?.setupForTest()
                guard observer != nil else { return }

                gestureRecognizer?.beginForTest(point: CGPoint(x: 100, y: 100), observer: observer)
                gestureRecognizer?.updateForTest(
                    point: CGPoint(x: 200, y: 100),
                    observer: observer
                )
            }

            xit("set's the player's velocity in the game") {
                expect(subject.game.player.physicsBody?.velocity).to(equal(CGVector(dx: 50, dy: 0)))
            }
        }

        xdescribe("when the user pans the screen") {
            var gestureRecognizer: UIPanGestureRecognizer!
            var observer: GestureObserver!

            beforeEach {
                gestureRecognizer = subject.sceneView.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }.first
                expect(gestureRecognizer).toNot(beNil())
                observer = gestureRecognizer?.setupForTest()

                gestureRecognizer?.beginForTest(point: CGPoint(x: 100, y: 100), observer: observer)
                gestureRecognizer?.updateForTest(
                    point: CGPoint(x: 200, y: 100),
                    observer: observer
                )
            }

            it("moves the camera") {
                guard let scene = subject.sceneView.scene else {
                    return fail("No scene set up")
                }
                expect(scene.camera?.position).to(equal(CGPoint(
                    x: (scene.size.width / 2) + 100,
                    y: (scene.size.height / 2)
                )))
            }

            describe("panning the camera more in the same gesture") {
                beforeEach {
                    gestureRecognizer?.updateForTest(
                        point: CGPoint(x: 200, y: 200),
                        observer: observer
                    )
                }

                it("moves the camera again, relative to the last update") {
                    guard let scene = subject.sceneView.scene else {
                        return fail("No scene set up")
                    }
                    expect(scene.camera?.position).to(equal(CGPoint(
                        x: (scene.size.width / 2) + 100,
                        y: (scene.size.height / 2) + 100
                    )))
                }
            }
        }
    }
}

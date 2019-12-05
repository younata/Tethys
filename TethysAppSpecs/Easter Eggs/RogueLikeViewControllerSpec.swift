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
            var directionalGestureRecognizer: DirectionalGestureRecognizer?
            var observer: DirectionalGestureObserver!

            beforeEach {
                directionalGestureRecognizer = subject.sceneView.gestureRecognizers?.compactMap { $0 as? DirectionalGestureRecognizer }.first
                expect(directionalGestureRecognizer).toNot(beNil())
                observer = directionalGestureRecognizer?.setupForTest()
                guard observer != nil else { return }

                directionalGestureRecognizer?.beginForTest(observer: observer)
                directionalGestureRecognizer?.updateForTest(
                    direction: CGVector(dx: 1, dy: 0),
                    observer: observer
                )
            }

            xit("set's the player's velocity in the game") {
                expect(subject.game.player.physicsBody?.velocity).to(equal(CGVector(dx: 50, dy: 0)))
            }
        }
    }
}

private extension DirectionalGestureRecognizer {
    func setupForTest() -> DirectionalGestureObserver {
        let observer = DirectionalGestureObserver()
        self.addTarget(observer, action: #selector(DirectionalGestureObserver.didRecognize(_:)))
        return observer
    }

    func beginForTest(observer: DirectionalGestureObserver, line: UInt = #line) {
        let observerCount = observer.observations.count
        let touch = FakeTouch()
        touch.currentLocation = CGPoint(x: 100, y: 100)

        self.touchesBegan([touch], with: UIEvent())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        expect(observer.observations, line: line).toEventually(haveCount(observerCount + 1))
    }

    func updateForTest(direction: CGVector, observer: DirectionalGestureObserver, line: UInt = #line) {
        let observerCount = observer.observations.count
        let touch = FakeTouch()
        touch.currentLocation = CGPoint(x: 100 + (direction.dx * 50), y: 100 + (direction.dy * 50))
        self.touchesMoved([touch], with: UIEvent())

        expect(observer.observations, line: line).toEventually(haveCount(observerCount + 1))
    }

    func endForTest(observer: DirectionalGestureObserver, line: UInt = #line) {
        let observerCount = observer.observations.count
        self.touchesEnded([], with: UIEvent())

        expect(observer.observations, line: line).toEventually(haveCount(observerCount + 1))
    }
}

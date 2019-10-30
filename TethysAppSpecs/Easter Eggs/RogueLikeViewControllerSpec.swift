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
    }
}

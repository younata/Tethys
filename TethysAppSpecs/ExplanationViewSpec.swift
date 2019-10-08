import Quick
import Nimble
@testable import Tethys

final class ExplanationViewSpec: QuickSpec {
    override func spec() {
        var subject: ExplanationView!

        beforeEach {
            subject = ExplanationView(frame: CGRect(x: 0, y: 0, width: 200, height: 60))
        }

        describe("accessibility") {
            it("is an accessibility element") {
                expect(subject.isAccessibilityElement).to(beTrue())
                expect(subject.accessibilityTraits).to(equal([.staticText]))
            }

            it("does not respond to user interaction") {
                expect(subject.isUserInteractionEnabled).to(beFalse())
            }
        }
    }
}

import Quick
import Nimble

import Tethys

final class BlankViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: BlankViewController!

        beforeEach {
            subject = BlankViewController()
            subject.view.layoutIfNeeded()
        }

        describe("theming") {
            it("sets the background color") {
                expect(subject.view.backgroundColor).to(equal(Theme.backgroundColor))
            }
        }
    }
}

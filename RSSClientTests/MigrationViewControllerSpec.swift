import Quick
import Nimble

import rNews

class MigrationViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: MigrationViewController!

        beforeEach {
            subject = MigrationViewController()

            subject.view.layoutIfNeeded()
        }

        it("dunno") {
            expect(subject.view).toNot(beNil())
        }
    }
}

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

        it("shows an activity indicator with a useful message") {
            expect(subject.activityIndicator.message) == "Optimizing your database, hang tight"
        }
    }
}

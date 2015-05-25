import Quick
import Nimble
import UIKit

class ActivityIndicatorSpec: QuickSpec {
    override func spec() {
        var subject : ActivityIndicator! = nil

        beforeEach {
            subject = ActivityIndicator()
        }

        describe("-configureWithMessage:") {
            beforeEach {
                subject.configureWithMessage("Hello World")
            }

            it("should set the message text") {
                expect(subject.message).to(equal("Hello World"))
            }
        }
    }
}

import Quick
import Nimble
import UIKit
import Tethys

class ActivityIndicatorSpec: QuickSpec {
    override func spec() {
        var subject: ActivityIndicator! = nil

        beforeEach {
            subject = ActivityIndicator()
        }

        describe("-configure(message:)") {
            beforeEach {
                subject.configure(message: "Hello World")
            }

            it("should set the message text") {
                expect(subject.message).to(equal("Hello World"))
            }
        }
    }
}

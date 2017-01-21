import Quick
import Nimble
import UIKit
import Tethys

class UnreadCounterSpec: QuickSpec {
    override func spec() {
        var subject: UnreadCounter! = nil

        beforeEach {
            subject = UnreadCounter(frame: CGRect.zero)
        }

        it("should be transparent") {
            expect(subject.backgroundColor).to(equal(UIColor.clear))
        }

        it("should default to not show the countlabel even when unread != 0") {
            expect(subject.hideUnreadText) == true
        }

        it("should hide the countLabel when unreadText is set") {
            subject.hideUnreadText = true
            expect(subject.countLabel.isHidden) == true
        }

        context("when unread is 0") {
            beforeEach {
                subject.unread = 0
            }

            it("should hide itself") {
                expect(subject.isHidden) == true
            }
        }

        context("when unread is not 0") {
            beforeEach {
                subject.unread = 1
            }

            it("should show itself") {
                expect(subject.isHidden) == false
            }

            it("should set the countLabel text") {
                expect(subject.countLabel.text).to(equal("1"))
            }
        }
    }
}

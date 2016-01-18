import Quick
import Nimble
import rNews
import UIKit_PivotalSpecHelper

class NotificationViewSpec: QuickSpec {
    override func spec() {
        var subject: NotificationView! = nil

        beforeEach {
            subject = NotificationView()
        }

        it("starts with hidden labels") {
            expect(subject.titleLabel.hidden) == true
            expect(subject.messageLabel.hidden) == true
        }

        describe("displaying") {
            beforeEach {
                UIView.pauseAnimations()
                subject.display("foo", message: "bar", animated: true)
            }

            afterEach {
                UIView.resetAnimations()
            }

            it("unhides the labels") {
                expect(subject.titleLabel.hidden) == false
                expect(subject.messageLabel.hidden) == false
            }

            it("sets the title and message texts") {
                expect(subject.titleLabel.text) == "foo"
                expect(subject.messageLabel.text) == "bar"
            }

            describe("hiding again") {
                beforeEach {
                    UIView.resumeAnimations()
                }

                it("re-hides the labels") {
                    expect(subject.titleLabel.hidden) == true
                    expect(subject.messageLabel.hidden) == true
                }

                it("unsets the title and message texts") {
                    expect(subject.titleLabel.text).to(beNil())
                    expect(subject.messageLabel.text).to(beNil())
                }
            }
        }

        describe("responding to themeRepository updates") {
            var themeRepository = FakeThemeRepository()

            beforeEach {
                themeRepository = FakeThemeRepository()
                themeRepository.theme = .Dark

                themeRepository.addSubscriber(subject)
            }

            it("updates the label's textColors") {
                expect(subject.titleLabel.textColor).to(equalColor(themeRepository.backgroundColor))
                expect(subject.messageLabel.textColor).to(equalColor(themeRepository.backgroundColor))
            }

            it("sets the background color to the tintcolor") {
                expect(subject.backgroundColor).to(equalColor(themeRepository.errorColor))
            }
        }
    }
}


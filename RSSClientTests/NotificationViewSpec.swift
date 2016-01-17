import Quick
import Nimble
import rNews

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
                subject.display("foo", message: "bar", animated: true)
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
                    subject.hide(false, delay: 0)
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
                expect(subject.titleLabel.textColor) == themeRepository.backgroundColor
                expect(subject.messageLabel.textColor) == themeRepository.backgroundColor
            }

            it("sets the background color to the tintcolor") {
                expect(subject.backgroundColor) == themeRepository.errorColor
            }
        }
    }
}


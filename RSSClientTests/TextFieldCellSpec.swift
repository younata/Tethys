import Quick
import Nimble
import rNews

class TextFieldCellSpec: QuickSpec {
    override func spec() {
        var subject: TextFieldCell! = nil
        var themeRepository: FakeThemeRepository! = nil

        beforeEach {
            subject = TextFieldCell()
            themeRepository = FakeThemeRepository()
            subject.themeRepository = themeRepository
        }

        fdescribe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should change the background") {
                expect(subject.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("should change the textField's textcolor") {
                expect(subject.textField.textColor).to(equal(themeRepository.textColor))
            }
        }

        describe("onTextChange") {
            var textChangeString: String? = nil
            beforeEach {
                textChangeString = nil
                subject.onTextChange = {str in
                    textChangeString = str
                }
            }

            context("when showValidator is true") {
                beforeEach {
                    subject.showValidator = true
                    if let delegate = subject.textField.delegate {
                        delegate.textField?(subject.textField, shouldChangeCharactersInRange: NSMakeRange(0, 0), replacementString: "textChanged")
                    }
                }

                it("should set the validator") {
                    let expectedState = ValidatorView.ValidatorState.Validating
                    expect(subject.validView.state).to(equal(expectedState))
                }

                it("should call onTextChange") {
                    expect(textChangeString).to(equal("textChanged"))
                }
            }

            context("when showValidator is false") {
                beforeEach {
                    if let delegate = subject.textField.delegate {
                        delegate.textField?(subject.textField, shouldChangeCharactersInRange: NSMakeRange(0, 0), replacementString: "textChanged")
                    }
                }

                it("should still call onTextChange") {
                    expect(textChangeString).to(equal("textChanged"))
                }
            }
        }
    }
}

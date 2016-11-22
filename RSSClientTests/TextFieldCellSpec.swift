import Quick
import Nimble
import rNews

class TextFieldCellSpec: QuickSpec {
    override func spec() {
        var subject: TextFieldCell! = nil
        var themeRepository: ThemeRepository! = nil

        beforeEach {
            subject = TextFieldCell()
            themeRepository = ThemeRepository(userDefaults: nil)
            subject.themeRepository = themeRepository
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("changes the background") {
                expect(subject.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("changes the textField's textcolor") {
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
                    subject.textField.text = "textChanged"
                    if let delegate = subject.textField.delegate {
                        _ = delegate.textFieldShouldReturn?(subject.textField)
                    } else { fail("no delegate") }
                }

                it("sets the validator") {
                    let expectedState = ValidatorView.ValidatorState.validating
                    expect(subject.validView.state).to(equal(expectedState))
                }

                it("calls onTextChange") {
                    expect(textChangeString).to(equal("textChanged"))
                }
            }

            context("when showValidator is false") {
                beforeEach {
                    subject.textField.text = "textChanged"
                    if let delegate = subject.textField.delegate {
                        _ = delegate.textFieldShouldReturn?(subject.textField)
                    } else { fail("no delegate") }
                }

                it("still calls onTextChange") {
                    expect(textChangeString).to(equal("textChanged"))
                }
            }
        }
    }
}

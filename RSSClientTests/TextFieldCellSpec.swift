import Quick
import Nimble
import rNews

class TextFieldCellSpec: QuickSpec {
    override func spec() {
        var subject: TextFieldCell! = nil

        beforeEach {
            subject = TextFieldCell()
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

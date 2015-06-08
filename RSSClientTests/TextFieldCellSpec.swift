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
            var expectation: XCTestExpectation! = nil
            beforeEach {
                expectation = self.expectationWithDescription("onTextChanged")
                subject.onTextChange = {str in
                    expect(str).to(equal("textChanged"))
                    expectation.fulfill()
                }
            }
            context("when showValidator is true") {
                beforeEach {
                    subject.showValidator = true
                    if let delegate = subject.textField.delegate {
                        delegate.textField!(subject.textField, shouldChangeCharactersInRange: NSMakeRange(0, 0), replacementString: "textChanged")
                    }
                }

                it("should set the validator") {
                    let expectedState = ValidatorView.ValidatorState.Validating
                    expect(subject.validView.state).to(equal(expectedState))
                }

                it("should call onTextChange") {
                    self.waitForExpectationsWithTimeout(1) { error in
                        expect(error).to(beNil())
                    }
                }
            }

            context("when showValidator is false") {
                beforeEach {
                    if let delegate = subject.textField.delegate {
                        delegate.textField!(subject.textField, shouldChangeCharactersInRange: NSMakeRange(0, 0), replacementString: "textChanged")
                    }
                }

                it("should call onTextChange") {
                    self.waitForExpectationsWithTimeout(1) { error in
                        expect(error).to(beNil())
                    }
                }
            }
        }
    }
}

import Quick
import Nimble
import rNews

class TextViewCellSpec: QuickSpec {
    override func spec() {
        var subject: TextViewCell! = nil

        beforeEach {
            subject = TextViewCell()
        }

        describe("onTextChange") {
            beforeEach {
                subject.onTextChange = {str in
                    expect(str).to(equal("didChange"))
                }
            }

            it("should should be called whenever the cell's textView's text changes") {
                subject.textView.text = "didChange"
                subject.textViewDidChange(subject.textView)
            }
        }
    }
}

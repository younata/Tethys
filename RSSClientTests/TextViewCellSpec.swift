import Quick
import Nimble
import rNews

class TextViewCellSpec: QuickSpec {
    override func spec() {
        var subject: TextViewCell! = nil
        var themeRepository: FakeThemeRepository! = nil

        beforeEach {
            subject = TextViewCell()
            themeRepository = FakeThemeRepository()
            subject.themeRepository = themeRepository
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should change the background color") {
                expect(subject.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("should update the textView") {
                expect(subject.textView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.textView.textColor).to(equal(themeRepository.textColor))
            }
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

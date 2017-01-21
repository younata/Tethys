import Quick
import Nimble
import Tethys

class TagPickerViewSpec: QuickSpec {
    override func spec() {
        var subject: TagPickerView! = nil
        let tags: [String] = ["a", "b", "abc", "123", "a1ra"]
        var lastSelectedText: String? = nil

        beforeEach {
            subject = TagPickerView()
            lastSelectedText = nil
            subject.configureWithTags(tags, onSelect: {text in
                lastSelectedText = text
            })
        }

        it("should not call the onSelect callback") {
            expect(lastSelectedText).to(beNil())
        }

        let pickerListsTags: ([String]) -> (Void) = {tagsList in
            if let dataSource = subject.picker.dataSource,
                let delegate = subject.picker.delegate {
                    expect(dataSource.numberOfComponents(in: subject.picker)).to(equal(1))
                    expect(dataSource.pickerView(subject.picker, numberOfRowsInComponent: 0)).to(equal(tagsList.count))
                    for (idx, tag) in tagsList.enumerated() {
                        expect(delegate.pickerView!(subject.picker, attributedTitleForRow: idx, forComponent: 0)?.string).to(equal(tag))
                    }
            }
        }

        it("should list all existing tags") {
            pickerListsTags(tags)
        }

        describe("filtering results") {
            beforeEach {
                if let delegate = subject.textField.delegate {
                    _ = delegate.textField?(subject.textField, shouldChangeCharactersIn: NSMakeRange(0, 0), replacementString: "a")
                }
            }

            it("should call the onSelect callback") {
                expect(lastSelectedText).to(equal("a"))
            }

            it("should filter the results") {
                pickerListsTags(["a", "abc", "a1ra"])
            }
        }

        describe("tapping a row") {
            beforeEach {
                if let delegate = subject.picker.delegate {
                    delegate.pickerView!(subject.picker, didSelectRow: 1, inComponent: 0) // b
                }
            }

            it("should call the onSelect callback") {
                expect(subject.textField.text).to(equal("b"))
                expect(lastSelectedText).to(equal("b"))
            }

            it("should filter the results") {
                pickerListsTags(["b", "abc"])
            }
        }
    }
}

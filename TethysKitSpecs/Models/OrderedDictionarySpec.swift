import Quick
import Nimble

@testable import TethysKit

final class OrderedDictionarySpec: QuickSpec {
    override func spec() {
        var subject: OrderedDictionary<String, String>!

        beforeEach {
            subject = OrderedDictionary()
        }

        it("basic insertion/retrieval") {
            subject["foo"] = "bar"
            subject["b"] = "a"
            expect(subject.values).to(equal(["bar", "a"]))

            subject["foo"] = "qux"
            expect(subject.values).to(equal(["qux", "a"]))
        }

        it("removeValue(forKey:)") {
            subject = ["foo": "bar", "baz": "qux"]
            expect(subject.removeValue(forKey: "foo")).to(equal("bar"))
            expect(subject["foo"]).to(beNil(), description: "Expected dictionary to not contain key 'foo', got \(subject.keys)")

            expect(subject.removeValue(forKey: "whatever")).to(beNil())
        }

        describe("iterating") {
            it("iterates in the order keys were added") {
                subject = ["foo": "bar", "baz": "abc"]
                subject["qux"] = "aaaa"

                var index = 0
                let expectedItems: [(key: String, value: String)] = [("foo", "bar"), ("baz", "abc"), ("qux", "aaaa")]
                print(Array(subject))
                for (key, value) in subject {
                    expect(key).to(equal(expectedItems[index].key))
                    expect(value).to(equal(expectedItems[index].value))
                    index += 1
                }
            }
        }
    }
}

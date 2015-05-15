import Quick
import Nimble

class EnclosureSpec: QuickSpec {
    override func spec() {
        describe("equality") {
            it("should report two enclosures created with a coredataenclosure with the same enclosureID as equal") {
                let ctx = managedObjectContext()
                let a = createEnclosure(ctx)
                let b = createEnclosure(ctx)

                expect(Enclosure(enclosure: a, article: nil)).toNot(equal(Enclosure(enclosure: b, article: nil)))
                expect(Enclosure(enclosure: a, article: nil)).to(equal(Enclosure(enclosure: a, article: nil)))
            }

            it("should report two enclosures not created with coredataenclosures with the same property equality as equal") {
                let a = Enclosure(url: NSURL(string: "http://example.com")!, kind: "", data: nil, article: nil)
                let b = Enclosure(url: NSURL(string: "http://example.com")!, kind: "text/text", data: nil, article: nil)
                let c = Enclosure(url: NSURL(string: "http://example.com")!, kind: "", data: nil, article: nil)

                expect(a).toNot(equal(b))
                expect(a).to(equal(c))
            }
        }
    }
}

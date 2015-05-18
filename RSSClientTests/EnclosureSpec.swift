import Quick
import Nimble

class EnclosureSpec: QuickSpec {
    override func spec() {
        var subject : Enclosure? = nil

        beforeEach {
            subject = Enclosure(url: NSURL(string: "http://example.com")!, kind: "", data: nil, article: nil)

            expect(subject).toNot(beNil())
        }

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

        describe("setting article") {
            var article : Article! = nil

            beforeEach {
                article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
                subject?.article = article
            }

            it("should add subject to the article's enclosures list") {
                if let sub = subject {
                    expect(article.enclosures).to(contain(sub))
                }
            }
        }

        describe("the updated flag") {
            it("should start negative") {
                expect(subject?.updated).to(beFalsy())
            }

            describe("when a property is changed") {
                it("such as url, updated should change to positive") {
                    subject?.url = NSURL(string: "http://example.com")!
                    expect(subject?.updated).to(beFalsy())
                    subject?.url = NSURL(string: "http://example.com/changed")!
                    expect(subject?.updated).to(beTruthy())
                }

                it("such as kind, updated should change to positive") {
                    subject?.kind = ""
                    expect(subject?.updated).to(beFalsy())
                    subject?.kind = "hello there"
                    expect(subject?.updated).to(beTruthy())
                }

                it("such as data, updated should change to positive") {
                    subject?.data = nil
                    expect(subject?.updated).to(beFalsy())
                    subject?.data = NSData()
                    expect(subject?.updated).to(beTruthy())
                }

                it("such as article, updated should change to positive") {
                    subject?.article = nil
                    expect(subject?.updated).to(beFalsy())
                    let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
                    subject?.article = article
                    expect(subject?.updated).to(beTruthy())
                }
            }
        }
    }
}

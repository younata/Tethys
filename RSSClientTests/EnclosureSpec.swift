import Quick
import Nimble

class EnclosureSpec: QuickSpec {
    override func spec() {
        var subject : Enclosure? = nil

        beforeEach {
            subject = Enclosure(url: NSURL(string: "http://example.com")!, kind: "", data: nil, article: nil)

            expect(subject).toNot(beNil())
        }

        describe("Equatable") {
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

        describe("changing article") {
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

            it("should remove subject from the article's enclosures list when that gets unset") {
                subject?.article = nil
                if let sub = subject {
                    expect(article.enclosures).toNot(contain(sub))
                }
            }

            it("should remove from the old and add to the new when changing articles") {
                let newArticle = Article(title: "bleh", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
                subject?.article = newArticle
                if let sub = subject {
                    expect(article.enclosures).toNot(contain(sub))
                    expect(newArticle.enclosures).to(contain(sub))
                }
            }
        }

        describe("the updated flag") {
            it("should start negative") {
                expect(subject?.updated).to(beFalsy())
            }

            describe("properties that change updated to positive") {
                it("url") {
                    subject?.url = NSURL(string: "http://example.com")!
                    expect(subject?.updated).to(beFalsy())
                    subject?.url = NSURL(string: "http://example.com/changed")!
                    expect(subject?.updated).to(beTruthy())
                }

                it("kind") {
                    subject?.kind = ""
                    expect(subject?.updated).to(beFalsy())
                    subject?.kind = "hello there"
                    expect(subject?.updated).to(beTruthy())
                }

                it("data") {
                    subject?.data = nil
                    expect(subject?.updated).to(beFalsy())
                    subject?.data = NSData()
                    expect(subject?.updated).to(beTruthy())
                }

                it("article") {
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

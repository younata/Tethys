import Quick
import Nimble

class ArticleSpec: QuickSpec {
    override func spec() {
        describe("equality") {
            it("should report two articles created with a coredataarticle with the same articleID as equal") {
                let ctx = managedObjectContext()
                let a = createArticle(ctx)
                let b = createArticle(ctx)

                expect(Article(article: a, feed: nil)).toNot(equal(Article(article: b, feed: nil)))
                expect(Article(article: a, feed: nil)).to(equal(Article(article: a, feed: nil)))
            }

            it("should report two articles not created with coredataarticles with the same property equality as equal") {
                let date = NSDate()
                let a = Article(title: "", link: nil, summary: "", author: "", published: date, updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
                let b = Article(title: "blah", link: NSURL(), summary: "hello", author: "anAuthor", published: NSDate(timeIntervalSince1970: 0), updatedAt: nil, identifier: "hi", content: "hello there", read: true, feed: nil, flags: ["flag"], enclosures: [])
                let c = Article(title: "", link: nil, summary: "", author: "", published: date, updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])

                expect(a).toNot(equal(b))
                expect(a).to(equal(c))
            }
        }

        describe("Hashable") {
            it("should report two articles created with a coredataarticle with the same articleID as having the same hashValue") {
                let ctx = managedObjectContext()
                let a = createArticle(ctx)
                let b = createArticle(ctx)

                expect(Article(article: a, feed: nil).hashValue).toNot(equal(Article(article: b, feed: nil).hashValue))
                expect(Article(article: a, feed: nil).hashValue).to(equal(Article(article: a, feed: nil).hashValue))
            }

            it("should report two articles not created with coredataarticles with the same property equality as having the same hashValue") {
                let date = NSDate()
                let a = Article(title: "", link: nil, summary: "", author: "", published: date, updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
                let b = Article(title: "blah", link: NSURL(), summary: "hello", author: "anAuthor", published: NSDate(timeIntervalSince1970: 0), updatedAt: nil, identifier: "hi", content: "hello there", read: true, feed: nil, flags: ["flag"], enclosures: [])
                let c = Article(title: "", link: nil, summary: "", author: "", published: date, updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])

                expect(a.hashValue).toNot(equal(b.hashValue))
                expect(a.hashValue).to(equal(c.hashValue))
            }
        }

        describe("updates") {

        }
    }
}

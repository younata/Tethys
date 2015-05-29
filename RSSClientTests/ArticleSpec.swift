import Quick
import Nimble
import rNews

class ArticleSpec: QuickSpec {
    override func spec() {
        var subject : Article! = nil

        beforeEach {
            subject = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [])
        }

        describe("Equatable") {
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

        describe("adding an enclosure") {
            var enclosure : Enclosure! = nil

            beforeEach {
                enclosure = Enclosure(url: NSURL(string: "http://example.com")!, kind: "", data: nil, article: nil)
            }

            context("when the enclosure is not associated with any article") {
                it("should add the enclosure and set the enclosure's article if it's not set already") {
                    subject.addEnclosure(enclosure)

                    expect(enclosure.updated).to(beTruthy())
                    expect(subject.updated).to(beTruthy())
                    expect(enclosure.article).to(equal(subject))
                    expect(subject.enclosures).to(contain(enclosure))
                }
            }

            context("when the enclosure is already associated with this article") {

                beforeEach {
                    subject = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [enclosure])

                    expect(enclosure.article).to(equal(subject))
                    expect(subject.enclosures).to(contain(enclosure))
                    expect(subject.updated).to(beFalsy())
                }

                it("essentially no-ops") {
                    subject.addEnclosure(enclosure)

                    expect(subject.updated).to(beFalsy())
                    expect(enclosure.article).to(equal(subject))
                    expect(subject.enclosures).to(contain(enclosure))
                }
            }

            context("when the enclosure is associated with a different article") {
                var otherArticle : Article! = nil

                beforeEach {
                    otherArticle = Article(title: "blah", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [enclosure])
                }

                it("should remove the enclosure from the other article and add it to this article") {
                    subject.addEnclosure(enclosure)

                    expect(enclosure.updated).to(beTruthy())
                    expect(subject.updated).to(beTruthy())
                    expect(otherArticle.updated).to(beTruthy())
                    expect(enclosure.article).to(equal(subject))
                    expect(subject.enclosures).to(contain(enclosure))
                    expect(otherArticle.enclosures).toNot(contain(enclosure))
                }
            }
        }

        describe("removing an enclosure") {
            var enclosure : Enclosure! = nil

            beforeEach {
                enclosure = Enclosure(url: NSURL(string: "http://example.com")!, kind: "", data: nil, article: nil)
            }

            context("when the enclosure is not associated with any article") {
                it("essentially no-ops") {
                    subject.removeEnclosure(enclosure)
                    expect(subject.updated).to(beFalsy())
                }
            }

            context("when the enclosure is associated with this article") {
                beforeEach {
                    subject = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [enclosure])
                    expect(enclosure.article).to(equal(subject))
                    expect(subject.enclosures).to(contain(enclosure))
                }

                it("should remove the enclosure from the article") {
                    subject.removeEnclosure(enclosure)
                    expect(subject.updated).to(beTruthy())
                    expect(subject.enclosures).toNot(contain(enclosure))
                    expect(enclosure.article).to(beNil())
                }
            }

            context("when the enclosure is associated with a different article") {
                var otherArticle : Article! = nil

                beforeEach {
                    otherArticle = Article(title: "blah", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: [], enclosures: [enclosure])
                }

                it("essentially no-ops") {
                    subject.removeEnclosure(enclosure)
                    expect(subject.updated).to(beFalsy())
                    expect(otherArticle.updated).to(beFalsy())
                }
            }
        }

        describe("adding a flag") {

            it("should add the flag") {
                subject.addFlag("flag")

                expect(subject.flags).to(contain("flag"))
                expect(subject.updated).to(beTruthy())
            }

            context("trying to add the same flag again") {
                beforeEach {
                    subject = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: ["flag"], enclosures: [])
                }

                it("should no-op") {
                    subject.addFlag("flag")

                    expect(subject.updated).to(beFalsy())
                }
            }
        }

        describe("removing a flag") {
            context("that is already a flag in the article") {
                it("should remove the flag") {
                    subject = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, feed: nil, flags: ["flag"], enclosures: [])
                    subject.removeFlag("flag")

                    expect(subject.flags).toNot(contain("flags"))
                    expect(subject.updated).to(beTruthy())
                }
            }

            context("that isn't in a flag in the article") {
                it("should no-op") {
                    expect(subject.flags).toNot(contain("flag"))
                    subject.removeFlag("flag")

                    expect(subject.flags).toNot(contain("flag"))
                    expect(subject.updated).to(beFalsy())
                }
            }
        }

        describe("changing feeds") {
            var feed : Feed! = nil

            beforeEach {
                feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)

                subject.feed = feed
            }

            it("should add subject to the feed's articles list") {
                expect(feed.articles).to(contain(subject))
            }

            it("should remove subject from the feed's articls list when that gets unset") {
                subject.feed = nil

                expect(feed.articles).toNot(contain(self))
            }

            it("should remove from the old and add to the new when changing feeds") {
                let newFeed = Feed(title: "blah", url: nil, summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)

                subject.feed = newFeed

                expect(feed.articles).toNot(contain(subject))
                expect(newFeed.articles).to(contain(subject))
            }
        }

        describe("the updated flag") {
            it("should start negative") {
                expect(subject.updated).to(beFalsy())
            }

            describe("properties that change updated to positive") {
                it("title") {
                    subject.title = ""
                    expect(subject.updated).to(beFalsy())
                    subject.title = "title"
                    expect(subject.updated).to(beTruthy())
                }

                it("link") {
                    subject.link = nil
                    expect(subject.updated).to(beFalsy())
                    subject.link = NSURL(string: "http://example.com")
                    expect(subject.updated).to(beTruthy())
                }

                it("summary") {
                    subject.summary = ""
                    expect(subject.updated).to(beFalsy())
                    subject.summary = "summary"
                    expect(subject.updated).to(beTruthy())
                }

                it("author") {
                    subject.author = ""
                    expect(subject.updated).to(beFalsy())
                    subject.author = "author"
                    expect(subject.updated).to(beTruthy())
                }

                it("published") {
                    subject.published = subject.published
                    expect(subject.updated).to(beFalsy())
                    subject.published = NSDate(timeIntervalSince1970: 0)
                    expect(subject.updated).to(beTruthy())
                }

                it("updatedAt") {
                    subject.updatedAt = nil
                    expect(subject.updated).to(beFalsy())
                    subject.updatedAt = NSDate()
                    expect(subject.updated).to(beTruthy())
                }

                it("identifier") {
                    subject.identifier = ""
                    expect(subject.updated).to(beFalsy())
                    subject.identifier = "identifier"
                    expect(subject.updated).to(beTruthy())
                }

                it("content") {
                    subject.content = ""
                    expect(subject.updated).to(beFalsy())
                    subject.content = "content"
                    expect(subject.updated).to(beTruthy())
                }

                it("read") {
                    subject.read = false
                    expect(subject.updated).to(beFalsy())
                    subject.read = true
                    expect(subject.updated).to(beTruthy())
                }

                it("feed") {
                    subject.feed = nil
                    expect(subject.updated).to(beFalsy())
                    subject.feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
                    expect(subject.updated).to(beTruthy())
                }

                it("flags") {
                    subject.addFlag("flag")
                    expect(subject.updated).to(beTruthy())
                }

                it("enclosures") {
                    subject.addEnclosure(Enclosure(url: NSURL(string: "http://example.com")!, kind: "", data: nil, article: nil))
                    expect(subject.updated).to(beTruthy())
                }
            }
        }
    }
}

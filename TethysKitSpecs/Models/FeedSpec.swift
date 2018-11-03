import Quick
import Nimble
import RealmSwift
@testable import TethysKit

class FeedSpec: QuickSpec {
    override func spec() {
        var subject: Feed! = nil
        var realm: Realm!

        beforeEach {
            let realmConf = Realm.Configuration(inMemoryIdentifier: "FeedSpec")
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            subject = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        }

        it("uses it's url as the title if the title is blank") {
            subject = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            expect(subject.displayTitle).to(equal("https://example.com"))
        }

        it("unreadArticles() should return articles with read->false") {
            func article(_ name: String, read: Bool) -> Article {
                return Article(title: name, link: URL(string: "https://example.com/article1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: read, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
            }

            let a = article("a", read: true)
            let b = article("b", read: false)
            let c = article("c", read: false)
            let d = article("d", read: true)

            subject.addArticle(a)
            subject.addArticle(b)
            subject.addArticle(c)
            subject.addArticle(d)

            expect(Array(subject.unreadArticles)).to(equal([b, c]))
        }

        describe("Equatable") {
            it("should report two feeds created with a realmfeed with the same url as equal") {
                let a = RealmFeed()
                a.url = "https://example.com/feed"
                let b = RealmFeed()
                b.url = "https://example.com/feed2"

                _ = try? realm.write {
                    realm.add(a)
                    realm.add(b)
                }

                expect(Feed(realmFeed: a)).toNot(equal(Feed(realmFeed: b)))
                expect(Feed(realmFeed: a)).to(equal(Feed(realmFeed: a)))
            }

            it("should report two feeds not created from datastores with the same property equality as equal") {
                let a = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let b = Feed(title: "blah", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let c = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                expect(a).toNot(equal(b))
                expect(a).to(equal(c))
            }
        }

        describe("Hashable") {
            it("should report two feeds created with a realmfeed with the same url as having the same hashValue") {
                let a = RealmFeed()
                a.url = "https://example.com/feed"
                let b = RealmFeed()
                b.url = "https://example.com/feed2"

                _ = try? realm.write {
                    realm.add(a)
                    realm.add(b)
                }

                expect(Feed(realmFeed: a).hashValue).toNot(equal(Feed(realmFeed: b).hashValue))
                expect(Feed(realmFeed: a).hashValue).to(equal(Feed(realmFeed: a).hashValue))
            }

            it("should report two feeds not created from datastores with the same property equality as having the same hashValue") {
                let a = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let b = Feed(title: "blah", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let c = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                expect(a.hashValue).toNot(equal(b.hashValue))
                expect(a.hashValue).to(equal(c.hashValue))
            }
        }

        describe("adding an article") {
            var article: Article! = nil
            beforeEach {
                article = Article(title: "", link: URL(string: "https://example.com/article1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
            }

            context("when the article is not associated with any article") {
                it("should add the article and set the article's feed if it's not set already") {
                    subject.addArticle(article)

                    expect(subject.updated) == true
                    expect(article.updated) == true
                    expect(article.feed).to(equal(subject))
                    expect(subject.articlesArray.contains(article)).to(beTruthy())
                }
            }

            context("when the article is already associated with this feed") {
                beforeEach {
                    subject = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [],
                                   waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                }

                it("essentially no-ops") {
                    subject.addArticle(article)
                    expect(subject.updated) == false
                    expect(article.feed).to(equal(subject))
                    expect(subject.articlesArray.contains(article)).to(beTruthy())
                }
            }

            context("when the article is associated with a different feed") {
                var otherFeed: Feed! = nil
                beforeEach {
                    otherFeed = Feed(title: "blah", url: URL(string: "https://example.com")!, summary: "", tags: [],
                                     waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                }

                it("should remove the article from the other feed and add it to this feed") {
                    subject.addArticle(article)

                    expect(subject.updated) == true
                    expect(article.updated) == true
                    expect(otherFeed.updated) == true
                    expect(article.feed).to(equal(subject))
                    expect(subject.articlesArray.contains(article)).to(beTruthy())
                    expect(otherFeed.articlesArray.contains(article)).toNot(beTruthy())
                }
            }
        }

        describe("removing an article") {
            var article: Article! = nil
            beforeEach {
                article = Article(title: "", link: URL(string: "https://example.com/article1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
            }

            context("when the article is not associated with any article") {
                it("essentially no-ops") {
                    subject.removeArticle(article)
                    expect(subject.updated) == false
                }
            }

            context("when the article is associated with this feed") {
                beforeEach {
                    subject = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [],
                                   waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                }

                it("removes the article and unsets the article's feed") {
                    subject.removeArticle(article)
                    expect(subject.updated) == true
                    expect(article.feed).to(beNil())
                    expect(subject.articlesArray.contains(article)).toNot(beTruthy())
                }
            }

            context("when the article is associated with a different feed") {
                var otherFeed: Feed! = nil
                beforeEach {
                    otherFeed = Feed(title: "blah", url: URL(string: "https://example.com")!, summary: "", tags: [],
                                     waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                }

                it("essentially no-ops") {
                    subject.removeArticle(article)
                    expect(subject.updated) == false
                    expect(otherFeed.updated) == false
                }
            }
        }

        describe("adding a tag") {
            it("should add the tag") {
                subject.addTag("tag")

                expect(subject.tags).to(contain("tag"))
                expect(subject.updated) == true
            }

            context("trying to add the same flag again") {
                beforeEach {
                    subject = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: ["tag"],
                        waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                }

                it("should no-op") {
                    subject.addTag("tag")

                    expect(subject.updated) == false
                }
            }

            describe("Adding a tag that starts with '~'") {
                beforeEach {
                    subject.addTag("~newTag")
                }

                it("should now report the title as the new tag minus the prefix'd '~'") {
                    expect(subject.displayTitle).to(equal("newTag"))
                }
            }

            describe("Adding a tag that starts with '`'") {
                beforeEach {
                    subject.addTag("`newTag")
                }

                it("should now report the summary as the new tag minus the prefix'd '`'") {
                    expect(subject.displaySummary).to(equal("newTag"))
                }
            }
        }

        describe("removing a tag") {
            context("that is already a flag in the article") {
                it("should remove the flag") {
                    subject = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: ["tag"],
                        waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    subject.removeTag("tag")

                    expect(subject.tags).toNot(contain("tags"))
                    expect(subject.updated) == true
                }
            }

            context("that isn't in a flag in the article") {
                it("should no-op") {
                    expect(subject.tags).toNot(contain("tag"))
                    subject.removeTag("tag")

                    expect(subject.tags).toNot(contain("tag"))
                    expect(subject.updated) == false
                }
            }
        }

        describe("the updated flag") {
            it("should start negative") {
                expect(subject.updated) == false
            }

            describe("properties that change updated to positive") {
                it("title") {
                    subject.title = ""
                    expect(subject.updated) == false
                    subject.title = "title"
                    expect(subject.updated) == true
                }

                it("url") {
                    subject.title = ""
                    expect(subject.updated) == false
                    subject.title = "title"
                    expect(subject.updated) == true
                }

                it("summary") {
                    subject.summary = ""
                    expect(subject.updated) == false
                    subject.summary = "summary"
                    expect(subject.updated) == true
                }

                it("tags") {
                    subject.addTag("tag")
                    expect(subject.updated) == true
                }

                it("waitPeriod") {
                    subject.waitPeriod = 0
                    expect(subject.updated) == false
                    subject.waitPeriod = 1
                    expect(subject.updated) == true
                }

                it("remainingWait") {
                    subject.remainingWait = 0
                    expect(subject.updated) == false
                    subject.remainingWait = 1
                    expect(subject.updated) == true
                }

                it("articles") {
                    let article = Article(title: "", link: URL(string: "https://example.com/article1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])
                    subject.addArticle(article)
                    expect(subject.updated) == true
                }

                it("image") {
                    subject.image = nil
                    expect(subject.updated) == false
                    subject.image = Image()
                    expect(subject.updated) == true
                }

                it("settings") {
                    subject.settings = nil
                    expect(subject.updated) == false
                    subject.settings = Settings(maxNumberOfArticles: 0)
                    expect(subject.updated) == true
                }
            }
        }
    }
}

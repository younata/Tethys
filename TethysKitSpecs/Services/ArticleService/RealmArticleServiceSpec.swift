import Quick
import Nimble
import RealmSwift
@testable import TethysKit


final class RealmArticleServiceSpec: QuickSpec {
    override func spec() {
        let realmConf = Realm.Configuration(inMemoryIdentifier: "RealmArticleServiceSpec")
        var realm: Realm!

        var mainQueue: FakeOperationQueue!
        var workQueue: FakeOperationQueue!

        var subject: RealmArticleService!

        beforeEach {
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            workQueue = FakeOperationQueue()
            workQueue.runSynchronously = true

            subject = RealmArticleService(
                realm: realm,
                mainQueue: mainQueue,
                workQueue: workQueue
            )
        }

        describe("feed(of:)") {
            it("returns the feed of the article") {
                realm.beginWrite()
                let realmFeed = RealmFeed()
                realmFeed.title = "Feed1"
                realmFeed.url = "https://example.com/feed/feed1"

                let realmArticle = RealmArticle()
                realmArticle.title = "article"
                realmArticle.link = "https://example.com/article/article1"
                realmArticle.feed = realmFeed

                realm.add(realmFeed)
                realm.add(realmArticle)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }

                let article = Article(realmArticle: realmArticle, feed: nil)

                expect(subject.feed(of: article).value?.value).to(equal(Feed(realmFeed: realmFeed)))
            }

            it("returns a database error if no feed is found") {
                realm.beginWrite()

                let realmArticle = RealmArticle()
                realmArticle.title = "article"
                realmArticle.link = "https://example.com/article/article1"
                realm.add(realmArticle)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }

                let article = Article(realmArticle: realmArticle, feed: nil)

                expect(subject.feed(of: article).value?.error).to(equal(TethysError.database(.entryNotFound)))
            }
        }

        describe("authors(of:)") {
            context("with one author") {
                it("returns the author's name") {
                    let article = articleFactory(authors: [
                        Author("An Author")
                        ])
                    expect(subject.authors(of: article)).to(equal("An Author"))
                }

                it("returns the author's name and email, if present") {
                    let article = articleFactory(authors: [
                        Author(name: "An Author", email: URL(string: "mailto:an@author.com"))
                        ])
                    expect(subject.authors(of: article)).to(equal("An Author <an@author.com>"))
                }
            }

            context("with two authors") {
                it("returns both authors names") {
                    let article = articleFactory(authors: [
                        Author("An Author"),
                        Author("Other Author", email: URL(string: "mailto:other@author.com"))
                    ])

                    expect(subject.authors(of: article)).to(equal("An Author, Other Author <other@author.com>"))
                }
            }

            context("with more authors") {
                it("returns them combined with commas") {
                    let article = articleFactory(authors: [
                        Author("An Author"),
                        Author("Other Author", email: URL(string: "mailto:other@author.com")),
                        Author("Third Author", email: URL(string: "mailto:third@other.com"))
                    ])

                    expect(subject.authors(of: article)).to(equal(
                        "An Author, Other Author <other@author.com>, Third Author <third@other.com>"
                    ))
                }
            }
        }

        describe("related(to:)") {
            var article1: RealmArticle!
            var article2: RealmArticle!
            var article3: RealmArticle!

            beforeEach {
                realm.beginWrite()
                article1 = RealmArticle()
                article1.title = "article"
                article1.link = "https://example.com/article/article1"

                article2 = RealmArticle()
                article2.title = "article2"
                article2.link = "https://example.com/article/article2"

                article2.relatedArticles.append(article1)
                article1.relatedArticles.append(article2)

                article3 = RealmArticle()
                article3.title = "article3"
                article3.link = "https://example.com/article/article3"

                realm.add(article1)
                realm.add(article2)
                realm.add(article3)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }
            }

            it("returns all articles related to the given article") {
                expect(subject.related(to: Article(realmArticle: article1, feed: nil)).value?.value).to(haveCount(1))
                expect(subject.related(to: Article(realmArticle: article1, feed: nil)).value?.value).to(contain(Article(realmArticle: article2, feed: nil)))

                expect(subject.related(to: Article(realmArticle: article2, feed: nil)).value?.value).to(haveCount(1))
                expect(subject.related(to: Article(realmArticle: article2, feed: nil)).value?.value).to(contain(Article(realmArticle: article1, feed: nil)))
            }

            it("returns nothing when no articles are related to the given one.") {
                expect(subject.related(to: Article(realmArticle: article3, feed: nil)).value?.value).to(beEmpty())
            }
        }

        describe("recordRelation(of:to:)") {
            var article1: RealmArticle!
            var article2: RealmArticle!
            var article3: RealmArticle!

            beforeEach {
                realm.beginWrite()
                article1 = RealmArticle()
                article1.title = "article"
                article1.link = "https://example.com/article/article1"

                article2 = RealmArticle()
                article2.title = "article2"
                article2.link = "https://example.com/article/article2"

                article3 = RealmArticle()
                article3.title = "article3"
                article3.link = "https://example.com/article/article3"

                realm.add(article1)
                realm.add(article2)
                realm.add(article3)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }
            }

            it("adds the articles as related to each other") {
                let result = subject.recordRelation(of: Article(realmArticle: article2, feed: nil), to: Article(realmArticle: article3, feed: nil))

                expect(result.value?.value).to(beVoid())

                expect(article2.relatedArticles).to(haveCount(1))
                expect(article2.relatedArticles).to(contain(article3))

                expect(article3.relatedArticles).to(haveCount(1))
                expect(article3.relatedArticles).to(contain(article2))
            }

            it("does nothing if the two articles are already related to each other") {
                realm.beginWrite()

                article2.relatedArticles.append(article3)
                article3.relatedArticles.append(article2)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }

                let result = subject.recordRelation(of: Article(realmArticle: article2, feed: nil), to: Article(realmArticle: article3, feed: nil))

                expect(result.value?.value).to(beVoid())

                expect(article2.relatedArticles).to(haveCount(1))
                expect(article2.relatedArticles).to(contain(article3))

                expect(article3.relatedArticles).to(haveCount(1))
                expect(article3.relatedArticles).to(contain(article2))
            }

            it("returns a database error if one of the articles isn't found in the database") {
                let result = subject.recordRelation(of: Article(realmArticle: article2, feed: nil), to: articleFactory())

                expect(result.value?.error).to(equal(TethysError.database(.entryNotFound)))
            }
        }

        describe("removeRelation(of:to:)") {
            var article1: RealmArticle!
            var article2: RealmArticle!
            var article3: RealmArticle!

            beforeEach {
                realm.beginWrite()
                article1 = RealmArticle()
                article1.title = "article"
                article1.link = "https://example.com/article/article1"

                article2 = RealmArticle()
                article2.title = "article2"
                article2.link = "https://example.com/article/article2"

                article3 = RealmArticle()
                article3.title = "article3"
                article3.link = "https://example.com/article/article3"

                realm.add(article1)
                realm.add(article2)
                realm.add(article3)

                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }
            }

            context("if a relation between the articles exists") {
                beforeEach {
                    realm.beginWrite()

                    article2.relatedArticles.append(article3)
                    article3.relatedArticles.append(article2)

                    do {
                        try realm.commitWrite()
                    } catch let exception {
                        dump(exception)
                        fail("Error writing to realm: \(exception)")
                    }
                }

                it("removes the relation") {
                    let result = subject.removeRelation(of: Article(realmArticle: article2, feed: nil), to: Article(realmArticle: article3, feed: nil))

                    expect(result.value?.value).to(beVoid())

                    expect(article2.relatedArticles).to(beEmpty())
                    expect(article3.relatedArticles).to(beEmpty())
                }
            }

            context("if a relation between the articles does not exist") {
                it("does nothing") {
                    let result = subject.removeRelation(of: Article(realmArticle: article2, feed: nil), to: Article(realmArticle: article3, feed: nil))

                    expect(result.value?.value).to(beVoid())
                }
            }

            context("if one or both of the articles aren't found in the database") {
                it("returns a database error") {
                    let result = subject.removeRelation(of: articleFactory(), to: articleFactory())

                    expect(result.value?.error).to(equal(TethysError.database(.entryNotFound)))
                }
            }
        }
    }
}

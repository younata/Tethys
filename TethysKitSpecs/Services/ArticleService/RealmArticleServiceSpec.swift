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
            let realmProvider = DefaultRealmProvider(configuration: realmConf)
            realm = realmProvider.realm()
            try! realm.write {
                realm.deleteAll()
            }

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            workQueue = FakeOperationQueue()
            workQueue.runSynchronously = true

            subject = RealmArticleService(
                realmProvider: realmProvider,
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
    }
}

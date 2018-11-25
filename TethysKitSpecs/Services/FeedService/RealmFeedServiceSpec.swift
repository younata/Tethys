import Quick
import Nimble
import Result
import CBGPromise
import RealmSwift

@testable import TethysKit

final class RealmFeedServiceSpec: QuickSpec {
    override func spec() {
        let realmConf = Realm.Configuration(inMemoryIdentifier: "RealmArticleServiceSpec")
        var realm: Realm!

        var mainQueue: FakeOperationQueue!
        var workQueue: FakeOperationQueue!

        var subject: RealmFeedService!

        var realmFeed1: RealmFeed!
        var realmFeed2: RealmFeed!
        var realmFeed3: RealmFeed!

        func write(_ transaction: () -> Void) {
            realm.beginWrite()

            transaction()

            do {
                try realm.commitWrite()
            } catch let exception {
                dump(exception)
                fail("Error writing to realm: \(exception)")
            }
        }

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

            subject = RealmFeedService(
                realmProvider: realmProvider,
                mainQueue: mainQueue,
                workQueue: workQueue
            )

            write {
                realmFeed1 = RealmFeed()
                realmFeed2 = RealmFeed()
                realmFeed3 = RealmFeed()

                for (index, feed) in [realmFeed1, realmFeed2, realmFeed3].enumerated() {
                    feed?.title = "Feed\(index + 1)"
                    feed?.url = "https://example.com/feed/feed\(index + 1)"

                    realm.add(feed!)
                }
            }
        }

        describe("feeds()") {
            var future: Future<Result<AnyCollection<Feed>, TethysError>>!
            // TODO: invoke an update service

            context("when none of the feeds have unread articles associated with them") {
                beforeEach {
                    future = subject.feeds()
                }

                it("resolves the future with all stored feeds, ordered by the title of the feed") {
                    guard let result = future.value?.value else {
                        fail("Expected to have the list of feeds, got \(String(describing: future.value))")
                        return
                    }

                    expect(Array(result)) == [
                        Feed(realmFeed: realmFeed1),
                        Feed(realmFeed: realmFeed2),
                        Feed(realmFeed: realmFeed3),
                    ]
                }
            }

            context("when some of the feeds have unread articles associated with them") {
                beforeEach {
                    write {
                        let unreadArticle = RealmArticle()
                        unreadArticle.title = "article1"
                        unreadArticle.link = "https://example.com/article/article1"
                        unreadArticle.read = false
                        unreadArticle.feed = realmFeed2

                        realm.add(unreadArticle)

                        let readArticle = RealmArticle()
                        readArticle.title = "article2"
                        readArticle.link = "https://example.com/article/article2"
                        readArticle.read = true
                        readArticle.feed = realmFeed3

                        realm.add(readArticle)
                    }

                    future = subject.feeds()
                }

                it("resolves the future all stored feeds, ordered first by unread count, then by the title of the feed") {
                    guard let result = future.value?.value else {
                        fail("Expected to have the list of feeds, got \(String(describing: future.value))")
                        return
                    }

                    expect(Array(result)) == [
                        Feed(realmFeed: realmFeed2),
                        Feed(realmFeed: realmFeed1),
                        Feed(realmFeed: realmFeed3),
                    ]
                }
            }
        }

        describe("articles(of:)") {
            var future: Future<Result<AnyCollection<Article>, TethysError>>!

            context("when the feed doesn't exist in the database") {
                beforeEach {
                    future = subject.articles(of: feedFactory())
                }

                it("resolves saying it couldn't find the feed in the database") {
                    expect(future.value?.error).to(equal(.database(.entryNotFound)))
                }
            }

            context("and the feed exists in the database") {
                var articles: [RealmArticle] = []
                beforeEach {
                    write {
                        articles = (0..<10).map { index in
                            let article = RealmArticle()
                            article.title = "article\(index)"
                            article.link = "https://example.com/article/article\(index)"
                            article.read = false
                            article.feed = realmFeed1
                            article.published = Date(timeIntervalSinceReferenceDate: TimeInterval(index))
                            realm.add(article)
                            return article
                        }
                    }

                    future = subject.articles(of: Feed(realmFeed: realmFeed1))
                }

                it("resolves the future with the articles, ordered most recent to least recent") {
                    guard let result = future.value?.value else {
                        fail("Expected to have the list of feeds, got \(String(describing: future.value))")
                        return
                    }

                    expect(Array(result)).to(equal(
                        articles.reversed().map { Article(realmArticle: $0, feed: nil) }
                    ))
                }
            }
        }

        describe("readAll(of:)") {
            var future: Future<Result<Void, TethysError>>!

            context("when the feed doesn't exist in the database") {
                beforeEach {
                    future = subject.readAll(of: feedFactory())
                }

                it("resolves saying it couldn't find the feed in the database") {
                    expect(future.value?.error).to(equal(.database(.entryNotFound)))
                }
            }

            context("when the feed exists in the database") {
                var articles: [RealmArticle] = []

                var otherArticles: [RealmArticle] = []
                beforeEach {
                    write {
                        articles = (0..<10).map { index in
                            let article = RealmArticle()
                            article.title = "article\(index)"
                            article.link = "https://example.com/article/article\(index)"
                            article.read = false
                            article.feed = realmFeed1
                            article.published = Date(timeIntervalSinceReferenceDate: TimeInterval(index))
                            realm.add(article)
                            return article
                        }

                        otherArticles = (0..<10).map { index in
                            let article = RealmArticle()
                            article.title = "article\(index)"
                            article.link = "https://example.com/article/article\(index)"
                            article.read = false
                            article.feed = realmFeed2
                            article.published = Date(timeIntervalSinceReferenceDate: TimeInterval(index))
                            realm.add(article)
                            return article
                        }
                    }

                    future = subject.readAll(of: Feed(realmFeed: realmFeed1))
                }

                it("marks all articles of the feed as read") {
                    for article in articles {
                        expect(article.read).to(beTrue())
                    }
                }

                it("doesnt mark articles of other feeds as read") {
                    for article in otherArticles {
                        expect(article.read).to(beFalse())
                    }
                }

                it("resolves the future") {
                    expect(future.value?.value).to(beVoid())
                }
            }
        }

        describe("remove(feed:)") {
            var future: Future<Result<Void, TethysError>>!

            context("when the feed doesn't exist in the database") {
                beforeEach {
                    future = subject.remove(feed: feedFactory())
                }

                it("resolves saying it couldn't find the feed in the database") {
                    expect(future.value?.error).to(equal(.database(.entryNotFound)))
                }
            }

            context("when the feed exists in the database") {
                var identifier: String!
                beforeEach {
                    identifier = realmFeed1.id
                    future = subject.remove(feed: Feed(realmFeed: realmFeed1))
                }

                it("deletes the feed") {
                    expect(realm.object(ofType: RealmFeed.self, forPrimaryKey: identifier)).to(beNil())
                }

                it("resolves the future") {
                    expect(future.value?.value).to(beVoid())
                }
            }
        }
    }
}

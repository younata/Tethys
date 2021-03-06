import Quick
import Nimble
import Result
import CBGPromise
import RealmSwift

@testable import TethysKit

final class RealmFeedServiceSpec: QuickSpec {
    override func spec() {
        let realmConf = Realm.Configuration(inMemoryIdentifier: "RealmFeedServiceSpec")
        var realm: Realm!

        var mainQueue: FakeOperationQueue!
        var workQueue: FakeOperationQueue!

        var updateService: FakeUpdateService!

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

            updateService = FakeUpdateService()

            subject = RealmFeedService(
                realmProvider: realmProvider,
                updateService: updateService,
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

            func itUpdatesTheFeeds(_ onSuccess: ([Feed]) -> Void) {
                describe("updating feeds") {
                    it("asks the update service to update each of the feeds") {
                        expect(updateService.updateFeedCalls).to(contain(
                            Feed(realmFeed: realmFeed1),
                            Feed(realmFeed: realmFeed2),
                            Feed(realmFeed: realmFeed3)
                        ))
                        expect(updateService.updateFeedCalls).to(haveCount(3))
                    }

                    describe("if all feeds successfully update") {
                        let feeds = [
                            feedFactory(title: "Feed1_Updated", unreadCount: 1),
                            feedFactory(title: "Feed2_Updated", unreadCount: 2),
                            feedFactory(title: "Feed3_Updated", unreadCount: 1)
                        ]
                        beforeEach {
                            updateService.updateFeedPromises.enumerated().forEach {
                                let (index, promise) = $0
                                promise.resolve(.success(feeds[index]))
                            }
                        }

                        onSuccess([
                            feeds[1],
                            feeds[0],
                            feeds[2]
                        ])
                    }

                    describe("if any feeds fail to update") {
                        let feeds = [
                            feedFactory(title: "Feed1_Updated"),
                            feedFactory(title: "Feed3_Updated")
                        ]
                        beforeEach {
                            guard updateService.updateFeedPromises.count == 3 else { return }
                            updateService.updateFeedPromises[0].resolve(.success(feedFactory(title: "Feed1_Updated")))
                            updateService.updateFeedPromises[2].resolve(.success(feedFactory(title: "Feed3_Updated")))
                            updateService.updateFeedPromises[1].resolve(.failure(.http(503)))
                        }

                        onSuccess(feeds)
                    }

                    describe("if all feeds fail to update") {
                        beforeEach {
                            updateService.updateFeedPromises.forEach { $0.resolve(.failure(.http(503))) }
                        }

                        it("resolves the future with an error") {
                            expect(future.value?.error).to(equal(
                                TethysError.multiple([
                                    .http(503),
                                    .http(503),
                                    .http(503)
                                ])
                            ))
                        }
                    }
                }
            }

            context("when none of the feeds have unread articles associated with them") {
                beforeEach {
                    future = subject.feeds()
                }

                itUpdatesTheFeeds { expectedFeeds in
                    it("resolves the future with all stored feeds, ordered by the title of the feed") {
                        expect(future).to(beResolved())
                        guard let result = future.value?.value else {
                            fail("Expected to have the list of feeds, got \(String(describing: future.value))")
                            return
                        }

                        expect(Array(result)).to(equal(expectedFeeds))
                    }
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

                itUpdatesTheFeeds { expectedFeeds in
                    it("resolves the future with all stored feeds, ordered first by unread count, then by the title of the feed") {
                        expect(future).to(beResolved())
                        guard let result = future.value?.value else {
                            fail("Expected to have the list of feeds, got \(String(describing: future.value))")
                            return
                        }

                        expect(Array(result)).to(equal(expectedFeeds))
                    }
                }
            }

            context("when there are no feeds in the database") {
                beforeEach {
                    try! realm.write {
                        realm.deleteAll()
                    }

                    future = subject.feeds()
                }

                it("resolves the future with .success([])") {
                    expect(future.value).toNot(beNil(), description: "Expected to resolve the future")
                    expect(future.value?.error).to(beNil(), description: "Expected to resolve successfully")

                    expect(future.value?.value).to(beEmpty(), description: "Expected to successfully resolve with no feeds")
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
                        articles.reversed().map { Article(realmArticle: $0) }
                    ))
                }
            }
        }

        describe("subscribe(to:)") {
            var future: Future<Result<Feed, TethysError>>!

            let url = URL(string: "https://example.com/feed")!

            context("if a feed with that url already exists in the database") {
                var existingFeed: RealmFeed!
                beforeEach {
                    write {
                        existingFeed = RealmFeed()
                        existingFeed.title = "Feed"
                        existingFeed.url = "https://example.com/feed"

                        realm.add(existingFeed)
                    }

                    future = subject.subscribe(to: url)
                }

                it("resolves the promise with the feed") {
                    expect(future.value?.value).to(equal(Feed(realmFeed: existingFeed)))
                }
            }

            context("if no feed with that url exists in the database") {
                beforeEach {
                    future = subject.subscribe(to: url)
                }

                it("creates a dummy feed with that url as it's only contents") {
                    expect(realm.objects(RealmFeed.self)).to(haveCount(4))

                    let feed = realm.objects(RealmFeed.self).first { $0.url == url.absoluteString }

                    expect(feed).toNot(beNil())
                    expect(feed?.title).to(equal(""))
                    expect(feed?.summary).to(equal(""))
                }

                it("does not yet resolve the future") {
                    expect(future).toNot(beResolved())
                }

                it("asks the UpdateService to update the feed") {
                    expect(updateService.updateFeedCalls).to(haveCount(1))

                    expect(updateService.updateFeedCalls.last).to(equal(Feed(
                        title: "",
                        url: url,
                        summary: "", tags: []
                    )))
                }

                describe("when the UpdateService succeeds") {
                    beforeEach {
                        updateService.updateFeedPromises.last?.resolve(.success(
                            Feed(realmFeed: realmFeed1)
                        ))
                    }

                    it("forwards the feed") {
                        expect(future.value?.value).to(equal(Feed(realmFeed: realmFeed1)))
                    }
                }

                describe("when the UpdateService fails") {
                    beforeEach {
                        updateService.updateFeedPromises.last?.resolve(.failure(TethysError.network(url, .unknown)))
                    }

                    it("forwards the error") {
                        expect(future.value?.error).to(equal(TethysError.network(url, .unknown)))
                    }
                }
            }
        }

        describe("tags()") {
            var future: Future<Result<AnyCollection<String>, TethysError>>!

            func realmString(for text: String) -> RealmString {
                return realm.object(ofType: RealmString.self, forPrimaryKey: text) ?? RealmString(string: text)
            }

            beforeEach {
                write {
                    for tag in ["a", "b", "c", "d"] {
                        realmFeed1.tags.append(realmString(for: tag))
                    }

                    realmFeed2.tags.append(realmString(for: "c"))

                    for tag in ["d", "e", "f"] {
                        realmFeed3.tags.append(realmString(for: tag))
                    }
                }

                future = subject.tags()
            }

            it("returns the set of all tags from all feeds, without any duplicates") {
                expect(future.value?.value?.sorted()) == [
                    "a", "b", "c", "d", "e", "f"
                ]
            }
        }

        describe("set(tags:of:)") {
            var future: Future<Result<Feed, TethysError>>!

            context("when the feed doesn't exist in the database") {
                beforeEach {
                    future = subject.set(tags: [], of: feedFactory())
                }

                it("resolves saying it couldn't find the feed in the database") {
                    expect(future.value?.error).to(equal(.database(.entryNotFound)))
                }
            }

            context("when the feed exists in the database") {
                beforeEach {
                    write {
                        realmFeed1.tags.append(RealmString(string: "qux"))
                    }

                    future = subject.set(tags: ["foo", "bar", "baz"], of: Feed(realmFeed: realmFeed1))
                }

                it("adds the listed tags to the set of tags on the feed") {
                    expect(realmFeed1.tags.map { $0.string }).to(contain(
                        "foo",
                        "bar",
                        "baz"
                    ))
                }

                it("removes tags that aren't listed in the set value") {
                    expect(realmFeed1.tags.map { $0.string }).toNot(contain("qux"))
                }

                it("resolves with a new feed object that has the set tags value") {
                    expect(future.value?.value).to(equal(Feed(
                        title: realmFeed1.title,
                        url: URL(string: realmFeed1.url)!,
                        summary: realmFeed1.summary,
                        tags: ["foo", "bar", "baz"]
                    )))
                }
            }
        }

        describe("set(url:on:)") {
            var future: Future<Result<Feed, TethysError>>!

            context("when the feed doesn't exist in the database") {
                beforeEach {
                    future = subject.set(url: URL(string: "https://example.com")!, on: feedFactory())
                }

                it("resolves saying it couldn't find the feed in the database") {
                    expect(future.value?.error).to(equal(.database(.entryNotFound)))
                }
            }

            context("when the feed exists in the database") {
                beforeEach {
                    future = subject.set(url: URL(string: "https://example.com/my_feed")!, on: Feed(realmFeed: realmFeed1))
                }

                it("sets the url on the feed object to the given url") {
                    expect(realmFeed1.url).to(equal("https://example.com/my_feed"))
                }

                it("resolves with a new feed object that has the updated url") {
                    expect(future.value?.value).to(equal(Feed(
                        title: realmFeed1.title,
                        url: URL(string: "https://example.com/my_feed")!,
                        summary: realmFeed1.summary,
                        tags: []
                    )))
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

                it("resolves successfully because there's nothing to do") {
                    expect(future.value?.value).to(beVoid())
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

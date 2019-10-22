import Quick
import Nimble
import Result
import CBGPromise
import RealmSwift

@testable import TethysKit

final class LocalRealmFeedServiceSpec: QuickSpec {
    override func spec() {
        let realmConf = Realm.Configuration(inMemoryIdentifier: "RealmFeedServiceSpec")
        var realm: Realm!

        var mainQueue: FakeOperationQueue!
        var workQueue: FakeOperationQueue!

        var updateService: FakeUpdateService!

        var subject: LocalRealmFeedService!

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

            subject = LocalRealmFeedService(
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

        describe("as a FeedService") {
            describe("feeds()") {
                var future: Future<Result<AnyCollection<Feed>, TethysError>>!

                context("when none of the feeds have unread articles associated with them") {
                    beforeEach {
                        future = subject.feeds()
                    }

                    it("resolves the future with all stored feeds, ordered by the title of the feed") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        guard let result = future.value?.value else {
                            fail("Expected to have the list of feeds, got \(String(describing: future.value))")
                            return
                        }

                        let expectedFeeds = [
                            feedFactory(title: realmFeed1.title, url: URL(string: realmFeed1.url)!, summary: "",
                                        tags: [], unreadCount: 0, image: nil),
                            feedFactory(title: realmFeed2.title, url: URL(string: realmFeed2.url)!, summary: "",
                                        tags: [], unreadCount: 0, image: nil),
                            feedFactory(title: realmFeed3.title, url: URL(string: realmFeed3.url)!, summary: "",
                                        tags: [], unreadCount: 0, image: nil),
                        ]

                        expect(Array(result)).to(equal(expectedFeeds))
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

                    it("resolves the future with all stored feeds, ordered first by unread count, then by the title of the feed") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        guard let result = future.value?.value else {
                            fail("Expected to have the list of feeds, got \(String(describing: future.value))")
                            return
                        }

                        let expectedFeeds = [
                            feedFactory(title: realmFeed2.title, url: URL(string: realmFeed2.url)!, summary: "",
                                        tags: [], unreadCount: 1, image: nil),
                            feedFactory(title: realmFeed1.title, url: URL(string: realmFeed1.url)!, summary: "",
                                        tags: [], unreadCount: 0, image: nil),
                            feedFactory(title: realmFeed3.title, url: URL(string: realmFeed3.url)!, summary: "",
                                        tags: [], unreadCount: 0, image: nil)
                        ]

                        expect(Array(result)).to(equal(expectedFeeds))
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

                    it("creates a feed with that url as it's only contents") {
                        expect(realm.objects(RealmFeed.self)).to(haveCount(4))

                        let feed = realm.objects(RealmFeed.self).first { $0.url == url.absoluteString }

                        expect(feed).toNot(beNil())
                        expect(feed?.title).to(equal(""))
                        expect(feed?.summary).to(equal(""))
                    }

                    it("resolves the future with that feed") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.value).to(equal(
                            feedFactory(title: "", url: url, summary: "", tags: [], unreadCount: 0, image: nil)
                        ))
                    }
                }
            }

            describe("tags()") {
                it("immediately resolves with error notSupported") {
                    let future = subject.tags()

                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.error).to(equal(.notSupported))
                }
            }

            describe("set(tags:of:)") {
                it("immediately resolves with error notSupported") {
                    let future = subject.set(tags: [], of: feedFactory())

                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.error).to(equal(.notSupported))
                }
            }

            describe("set(url:on:)") {
                it("immediately resolves with error notSupported") {
                    let future = subject.set(url: URL(string: "https://example.com/whatever")!, on: feedFactory())

                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.error).to(equal(.notSupported))
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

        describe("as a LocalFeedService") {
            describe("updateFeeds(with:)") {
                let feeds = [
                    feedFactory(title: "Updated 1", url: URL(string: "https://example.com/feed/feed1")!, summary: "Updated Summary 1",
                                tags: ["a", "b", "c"], unreadCount: 0, image: nil),
                    feedFactory(title: "Brand New Feed", url: URL(string: "https://example.com/brand_new_feed")!,
                                summary: "some summary", tags: [], unreadCount: 0, image: nil)
                ]

                var future: Future<Result<Void, TethysError>>!

                beforeEach {
                    future = subject.updateFeeds(with: AnyCollection(feeds))
                }

                it("updates the existing feeds that match (based off URL) with the new data") {
                    realmFeed1 = realm.object(ofType: RealmFeed.self, forPrimaryKey: realmFeed1.id)

                    expect(realmFeed1.title).to(equal("Updated 1"))
                    expect(realmFeed1.summary).to(equal("Updated Summary 1"))
                    expect(Array(realmFeed1.tags.map { $0.string })).to(equal(["a", "b", "c"]))
                }

                it("does not delete other feeds that weren't in the network list") {
                    expect(realm.object(ofType: RealmFeed.self, forPrimaryKey: realmFeed2.id)).toNot(beNil())
                    expect(realm.object(ofType: RealmFeed.self, forPrimaryKey: realmFeed3.id)).toNot(beNil())
                }

                it("inserts new feeds that the updated list found") {
                    let newFeed = realm.objects(RealmFeed.self).first { $0.url == "https://example.com/brand_new_feed" }
                    expect(newFeed).toNot(beNil())
                    expect(newFeed?.title).to(equal("Brand New Feed"))
                    expect(newFeed?.summary).to(equal("some summary"))
                    expect(newFeed?.tags).to(beEmpty())
                }

                it("resolves the promise successfully") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.value).to(beVoid())
                }
            }

            describe("updateFeed(from:)") {
                var future: Future<Result<Feed, TethysError>>!

                context("when that feed's url does not exist in the database") {
                    beforeEach {
                        future = subject.updateFeed(from: feedFactory())
                    }

                    it("resolves with an entryNotFound error") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(equal(.database(.entryNotFound)))
                    }
                }

                context("when that feed's url exists in the database") {
                    let updatedFeed = feedFactory(
                        title: "Updated 1", url: URL(string: "https://example.com/feed/feed1")!,
                        summary: "Updated Summary 1", tags: ["a", "b", "c"], unreadCount: 0, image: nil)

                    beforeEach {
                        future = subject.updateFeed(from: updatedFeed)
                    }

                    it("inserts new feeds that the updated list found") {
                        let newFeed = realm.objects(RealmFeed.self).first { $0.url == "https://example.com/brand_new_feed" }
                        expect(newFeed).toNot(beNil())
                        expect(newFeed?.title).to(equal("Brand New Feed"))
                        expect(newFeed?.summary).to(equal("some summary"))
                        expect(newFeed?.tags).to(beEmpty())
                    }

                    it("resolves the promise successfully") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.value).to(equal(updatedFeed))
                    }
                }
            }
        }
    }
}

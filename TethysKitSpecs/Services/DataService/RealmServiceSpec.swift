import Quick
import Nimble
import RealmSwift
import CBGPromise
import Result
@testable import TethysKit
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
#endif


class RealmServiceSpec: QuickSpec {
    override func spec() {
        let realmConf = Realm.Configuration(inMemoryIdentifier: "RealmServiceSpec")
        var realm = try! Realm(configuration: realmConf)
        try! realm.write {
            realm.deleteAll()
        }

        var mainQueue = FakeOperationQueue()
        mainQueue.runSynchronously = true
        var searchIndex = FakeSearchIndex()

        var subject = RealmService(realmConfiguration: realmConf, mainQueue: mainQueue, workQueue: mainQueue, searchIndex: searchIndex)

        beforeEach {
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            searchIndex = FakeSearchIndex()

            subject = RealmService(realmConfiguration: realmConf, mainQueue: mainQueue, workQueue: mainQueue, searchIndex: searchIndex)
        }

        describe("create operations") {
            it("new feed creates a new feed object") {
                _ = subject.createFeed(url: URL(string: "https://example.com/feed")!) { feed in
                    feed.title = "Hello"
                }.wait()

                let feeds = realm.objects(RealmFeed.self)
                expect(feeds.count) == 1
                guard let feed = feeds.first else { return }
                expect(feed.title) == "Hello"
                expect(feed.url) == "https://example.com/feed"
            }

            it("new article creates a new article object") {
                let expectation = self.expectation(description: "Create Article")

                subject.createArticle(url: URL(string: "https://example.com/article")!, feed: nil) { article in
                    article.title = "Hello"
                    expectation.fulfill()
                }

                self.waitForExpectations(timeout: 1, handler: nil)

                let articles = realm.objects(RealmArticle.self)
                expect(articles.count) == 1
                guard let article = articles.first else { return }
                expect(article.title) == "Hello"
            }

            it("can batch create things") {
                _ = subject.batchCreate(feedURLs: [URL(string: "https://example.com/1")!, URL(string: "https://example.com/2")!],
                                        articleURLs: [URL(string: "https://example.com/1")!, URL(string: "https://example.com/2")!,  URL(string: "https://example.com/3")!]).wait()

                expect(realm.objects(RealmFeed.self).count) == 2
                expect(realm.objects(RealmArticle.self).count) == 3
            }
        }

        describe("findOrCreateFeed") {
            beforeEach {
                realm.beginWrite()
                let realmFeed1 = RealmFeed()
                realmFeed1.title = "feed1"
                realmFeed1.url = "https://example.com/feed/feed1"

                for object in [realmFeed1] {
                    realm.add(object)
                }
                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }
            }

            it("finds an existing feed if that url exists") {
                let future = subject.findOrCreateFeed(url: URL(string: "https://example.com/feed/feed1")!)
                expect(future.value).toNot(beNil())
                let feed = future.value
                expect(feed?.url) == URL(string: "https://example.com/feed/feed1")

                let feeds = realm.objects(RealmFeed.self)
                expect(feeds.count) == 1
            }

            it("creates a new feed if that url does not exist") {
                let future = subject.findOrCreateFeed(url: URL(string: "https://example.com/feed/feed2")!)
                expect(future.value).toNot(beNil())
                let feed = future.value
                expect(feed?.url) == URL(string: "https://example.com/feed/feed2")

                let feeds = realm.objects(RealmFeed.self)
                expect(feeds.count) == 2
            }
        }

        describe("findOrCreateArticle") {
            var feed1: Feed! = nil
            beforeEach {
                realm.beginWrite()
                let realmFeed1 = RealmFeed()
                realmFeed1.title = "Feed1"
                realmFeed1.url = "https://example.com/feed/feed1"

                let realmArticle1 = RealmArticle()
                realmArticle1.title = "article"
                realmArticle1.link = "https://example.com/article/article1"
                realmArticle1.feed = realmFeed1

                let realmArticle2 = RealmArticle()
                realmArticle2.title = "http article"
                realmArticle2.link = "http://example.com/article/article10"
                realmArticle2.feed = realmFeed1

                for object in [realmFeed1, realmArticle1, realmArticle2] {
                    realm.add(object)
                }
                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }

                feed1 = Feed(realmFeed: realmFeed1)
            }

            it("finds an existing article if an article of that feed for that url exists") {
                let future = subject.findOrCreateArticle(feed: feed1, url: URL(string: "https://example.com/article/article1")!)
                expect(future.value).toNot(beNil())
                let article = future.value
                expect(article?.link) == URL(string: "https://example.com/article/article1")
                expect(article?.feed) == feed1

                expect(realm.objects(RealmFeed.self).count) == 1
                expect(realm.objects(RealmArticle.self).count) == 2
            }

            it("returns the existing article if an article of that feed for the https version of the url exists") {
                let future = subject.findOrCreateArticle(feed: feed1, url: URL(string: "http://example.com/article/article1")!)
                expect(future.value).toNot(beNil())
                let article = future.value
                expect(article?.link) == URL(string: "https://example.com/article/article1")
                expect(article?.feed) == feed1

                expect(realm.objects(RealmFeed.self).count) == 1
                expect(realm.objects(RealmArticle.self).count) == 2
            }

            it("returns the existing article if an article of that feed for the https version of the url exists") {
                let future = subject.findOrCreateArticle(feed: feed1, url: URL(string: "https://example.com/article/article10")!)
                expect(future.value).toNot(beNil())
                let article = future.value
                expect(article?.link) == URL(string: "http://example.com/article/article10")
                expect(article?.feed) == feed1

                expect(realm.objects(RealmFeed.self).count) == 1
                expect(realm.objects(RealmArticle.self).count) == 2
            }

            it("creates a new article if that url does not exist") {
                let future = subject.findOrCreateArticle(feed: feed1, url: URL(string: "https://example.com/article/article2")!)
                expect(future.value).toNot(beNil())
                let article = future.value
                expect(article?.link) == URL(string: "https://example.com/article/article2")
                expect(article?.feed) == feed1

                expect(realm.objects(RealmFeed.self).count) == 1
                expect(realm.objects(RealmArticle.self).count) == 3
            }

            it("creates a new feed and article if the feed does not exist") {
                let feed2 = Feed(title: "feed2", url: URL(string: "https://example.com/feed/feed2")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let future = subject.findOrCreateArticle(feed: feed2, url: URL(string: "https://example.com/article/article2")!)
                expect(future.value).toNot(beNil())
                let article = future.value
                expect(article?.link) == URL(string: "https://example.com/article/article2")
                expect(article?.feed) == feed2

                expect(realm.objects(RealmFeed.self).count) == 2
                expect(realm.objects(RealmArticle.self).count) == 3
            }
        }

        describe("after creates") {
            var feed1: TethysKit.Feed!
            var feed2: TethysKit.Feed!
            var article1: TethysKit.Article!
            var article2: TethysKit.Article!
            var article3: TethysKit.Article!

            beforeEach {
                realm.beginWrite()
                let realmFeed1 = RealmFeed()
                let realmFeed2 = RealmFeed()
                realmFeed1.title = "feed1"
                realmFeed1.url = "https://example.com/feed/feed1"
                realmFeed2.title = "feed2"
                realmFeed2.url = "https://example.com/feed/feed2"

                let realmArticle1 = RealmArticle()
                let realmArticle2 = RealmArticle()
                let realmArticle3 = RealmArticle()

                realmArticle1.title = "article1"
                realmArticle1.link = "https://example.com/article1"
                realmArticle1.published = Date(timeIntervalSince1970: 15)

                realmArticle2.title = "article2"
                realmArticle2.link = "https://example.com/article2"
                realmArticle2.published = Date(timeIntervalSince1970: 10)

                realmArticle3.title = "article3"
                realmArticle3.link = "https://example.com/article3"
                realmArticle3.published = Date(timeIntervalSince1970: 5)

                realmArticle1.feed = realmFeed1
                realmArticle2.feed = realmFeed1
                realmArticle3.feed = realmFeed2

                realmArticle3.relatedArticles.append(realmArticle2)
                realmArticle2.relatedArticles.append(realmArticle3)

                for object in [realmFeed1, realmFeed2, realmArticle1, realmArticle2, realmArticle3] {
                    realm.add(object)
                }
                do {
                    try realm.commitWrite()
                } catch let exception {
                    dump(exception)
                    fail("Error writing to realm: \(exception)")
                }

                feed1 = Feed(realmFeed: realmFeed1)
                feed2 = Feed(realmFeed: realmFeed2)

                article1 = Article(realmArticle: realmArticle1, feed: feed1)
                article2 = Article(realmArticle: realmArticle2, feed: feed1)
                article3 = Article(realmArticle: realmArticle3, feed: feed2)
            }

            describe("read operations") {
                it("reads the feeds based on the predicate") {
                    let res: Result<DataStoreBackedArray<Feed>, TethysError> = subject.allFeeds().wait()!
                    guard case let Result.success(values) = res else { fail(); return }
                    expect(Array(values)) == [feed1, feed2]
                }

                it("reads the articles based on the predicate") {
                    let allExpectation = self.expectation(description: "Read all articles")
                    _ = subject.articlesMatchingPredicate(NSPredicate(value: true)).then {
                        guard case let Result.success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1, article2, article3]

                        expect(articles[1].relatedArticles.contains(article3)).to(beTruthy())
                        expect(articles[2].relatedArticles.contains(article2)).to(beTruthy())

                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectation(description: "Read some articles")
                    _ = subject.articlesMatchingPredicate(NSPredicate(format: "title == %@", "article1")).then {
                        guard case let Result.success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectations(timeout: 1, handler: nil)
                }
            }

            describe("update operations") {
                it("doesn't create multiple copies of the same RealmString when a feed is saved") {
                    feed1.addTag("hello")
                    feed1.addTag("goodbye")
                    _ = subject.batchSave([feed1], articles: []).wait()

                    expect(realm.objects(RealmString.self).count) == 2

                    _ = subject.batchSave([feed1], articles: []).wait()

                    expect(realm.objects(RealmString.self).count) == 2
                }

                it("doesn't create multiple copies of the same RealmAuthor when an article is saved again") {
                    article1.authors = [
                        Author(name: "hello", email: URL(string: "goodbye"))
                    ]
                    _ = subject.batchSave([], articles: [article1]).wait()

                    expect(realm.objects(RealmAuthor.self).count) == 1

                    _ = subject.batchSave([], articles: [article1]).wait()
                    expect(realm.objects(RealmAuthor.self).count) == 1
                }

                it("inserts a RealmSettings if a Settings object is added to the feed") {
                    feed1.settings = Settings(maxNumberOfArticles: 30)
                    _ = subject.batchSave([feed1], articles: []).wait()

                    expect(realm.objects(RealmSettings.self).count) == 1

                    let recreatedFeed = subject.findOrCreateFeed(url: feed1.url).wait()

                    expect(recreatedFeed?.settings?.maxNumberOfArticles) == 30

                    _ = subject.batchSave([recreatedFeed!], articles: []).wait()

                    expect(realm.objects(RealmSettings.self).count) == 1
                }

                it("removes old articles if they exceed a settings max article count when that is changed") {
                    feed1.settings = Settings(maxNumberOfArticles: 1)
                    _ = subject.batchSave([feed1], articles: []).wait()

                    expect(realm.objects(RealmArticle.self).count) == 2

                    let recreatedFeed = subject.findOrCreateFeed(url: feed1.url).wait()!

                    expect(Array(recreatedFeed.articlesArray)) == [article1]
                }

                it("removes old articles when new articles are added and the max article count is exceeded") {
                    feed1.settings = Settings(maxNumberOfArticles: 2)
                    _ = subject.batchSave([feed1], articles: []).wait()

                    expect(realm.objects(RealmArticle.self).count) == 3

                    let recreatedFeed1 = subject.findOrCreateFeed(url: feed1.url).wait()!

                    expect(Array(recreatedFeed1.articlesArray)) == [article1, article2]

                    let _ = subject.findOrCreateArticle(feed: feed1, url: URL(string: "https://example.com/article5")!).wait()!

                    subject.batchSave([feed1], articles: [])

                    expect(realm.objects(RealmArticle.self).count) == 3

                    expect(Array(recreatedFeed1.articlesArray)) == [article1, article2]
                }

                #if os(iOS)
                    it("on iOS, updates the search index when an article is updated") {
                        article1.summary = "Hello world!"

                        _ = subject.batchSave([], articles: [article1]).wait()

                        expect(searchIndex.lastItemsAdded.count).to(equal(1))
                        if let item = searchIndex.lastItemsAdded.first as? CSSearchableItem {
                            let identifier = article1.identifier
                            expect(item.uniqueIdentifier).to(equal(identifier))
                            expect(item.domainIdentifier).to(beNil())
                            expect(item.expirationDate).to(equal(Date.distantFuture))
                            let attributes = item.attributeSet
                            expect(attributes.contentType).to(equal(kUTTypeHTML as String))
                            expect(attributes.title).to(equal(article1.title))
                            let keywords = ["article"] + article1.feed!.title.components(separatedBy: NSCharacterSet.whitespacesAndNewlines)
                            expect(attributes.keywords).to(equal(keywords))
                            expect(attributes.url).to(equal(article1.link))
                            expect(attributes.timestamp).to(equal(article1.updatedAt ?? article1.published))
                            let authorNames = article1.authors.map({ $0.description })
                            expect(attributes.authorNames) == authorNames
                            expect(attributes.contentDescription) == "Hello world!"
                        }
                    }
                #endif
            }

            describe("delete operations") {
                it("deletes feeds") {
                    let expectation = self.expectation(description: "delete feed")

                    let articleIdentifiers = feed1.articlesArray.map { $0.identifier }

                    _ = subject.deleteFeed(feed1).then {
                        guard case Result.success() = $0 else { return }
                        expectation.fulfill()
                    }

                    self.waitForExpectations(timeout: 1, handler: nil)

                    #if os(iOS)
                        expect(searchIndex.lastItemsDeleted) == articleIdentifiers
                    #endif

                    let feed = realm.object(ofType: RealmFeed.self, forPrimaryKey: feed1.feedID!)
                    expect(feed).to(beNil())
                }

                it("deletes articles") {
                    let expectation = self.expectation(description: "delete article")

                    _ = subject.deleteArticle(article1).then {
                        guard case Result.success() = $0 else { return }
                        expectation.fulfill()
                    }

                    self.waitForExpectations(timeout: 1, handler: nil)


                    #if os(iOS)
                        expect(searchIndex.lastItemsDeleted).to(contain(article1.identifier))
                    #endif

                    let article = realm.object(ofType: RealmArticle.self, forPrimaryKey: article1.articleID!)
                    expect(article).to(beNil())
                }
            }
        }

        dataServiceSharedSpec(subject, spec: self)
    }
}

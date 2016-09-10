import Quick
import Nimble
import RealmSwift
import CBGPromise
import Result
@testable import rNewsKit
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
                let expectation = self.expectationWithDescription("Create Feed")

                subject.createFeed { feed in
                    feed.title = "Hello"
                    feed.url = URL(string: "https://example.com/feed")!
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1, handler: nil)

                let feeds = realm.objects(RealmFeed)
                expect(feeds.count) == 1
                guard let feed = feeds.first else { return }
                expect(feed.title) == "Hello"
                expect(feed.url) == "https://example.com/feed"
            }

            it("new article creates a new article object") {
                let expectation = self.expectationWithDescription("Create Article")

                subject.createArticle(nil) { article in
                    article.title = "Hello"
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1, handler: nil)

                let articles = realm.objects(RealmArticle)
                expect(articles.count) == 1
                guard let article = articles.first else { return }
                expect(article.title) == "Hello"
            }

            it("can batch create things") {
                let expectation = self.expectationWithDescription("Batch Create")

                subject.batchCreate(2, articleCount: 3).then { _ in
                    expectation.fulfill()
                }

                expect(realm.objects(RealmFeed).count) == 2
                expect(realm.objects(RealmArticle).count) == 3
            }
        }

        describe("after creates") {
            var feed1: rNewsKit.Feed!
            var feed2: rNewsKit.Feed!
            var article1: rNewsKit.Article!
            var article2: rNewsKit.Article!
            var article3: rNewsKit.Article!

            beforeEach {
                realm.beginWrite()
                let realmFeed1 = RealmFeed()
                let realmFeed2 = RealmFeed()
                realmFeed1.title = "feed1"
                realmFeed2.title = "feed2"

                let realmArticle1 = RealmArticle()
                let realmArticle2 = RealmArticle()
                let realmArticle3 = RealmArticle()

                realmArticle1.title = "article1"
                realmArticle1.link = "https://example.com/article1"
                realmArticle1.published = Date(timeIntervalSince1970: 15)
                realmArticle2.title = "article2"
                realmArticle2.published = Date(timeIntervalSince1970: 10)
                realmArticle3.title = "article3"
                realmArticle3.published = Date(timeIntervalSince1970: 5)
                realmArticle1.feed = realmFeed1
                realmArticle2.feed = realmFeed1
                realmArticle3.feed = realmFeed2

                realmArticle3.relatedArticles.append(realmArticle2)
                realmArticle2.relatedArticles.append(realmArticle3)

                for object in [realmFeed1, realmFeed2, realmArticle1, realmArticle2, realmArticle3] {
                    realm.add(object)
                }
                _ = try? realm.commitWrite()

                feed1 = Feed(realmFeed: realmFeed1)
                feed2 = Feed(realmFeed: realmFeed2)

                article1 = Article(realmArticle: realmArticle1, feed: feed1)
                article2 = Article(realmArticle: realmArticle2, feed: feed1)
                article3 = Article(realmArticle: realmArticle3, feed: feed2)
            }

            describe("read operations") {
                it("reads the feeds based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all feeds")
                    subject.allFeeds().then {
                        guard case let Result.success(values) = $0 else { return }
                        expect(Array(values)) == [feed1, feed2]
                        allExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }

                it("reads the articles based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all articles")
                    subject.articlesMatchingPredicate(NSPredicate(value: true)).then {
                        guard case let Result.success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1, article2, article3]

                        expect(articles[1].relatedArticles).to(contain(article3))
                        expect(articles[2].relatedArticles).to(contain(article2))

                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectationWithDescription("Read some articles")
                    subject.articlesMatchingPredicate(NSPredicate(format: "title == %@", "article1")).then {
                        guard case let Result.success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }

            describe("update operations") {
                it("doesn't create multiple copies of the same RealmString when a feed is saved") {
                    feed1.addTag("hello")
                    feed1.addTag("goodbye")
                    subject.batchSave([feed1], articles: []).wait()

                    expect(realm.objects(RealmString).count) == 2

                    subject.batchSave([feed1], articles: []).wait()

                    expect(realm.objects(RealmString).count) == 2
                }

                it("doesn't create multiple copies of the same RealmAuthor when an article is saved again") {
                    article1.authors = [
                        Author(name: "hello", email: URL(string: "goodbye"))
                    ]
                    subject.batchSave([], articles: [article1]).wait()

                    expect(realm.objects(RealmAuthor).count) == 1

                    subject.batchSave([], articles: [article1]).wait()
                    expect(realm.objects(RealmAuthor).count) == 1
                }

                #if os(iOS)
                    it("on iOS, updates the search index when an article is updated") {
                        let expectation = self.expectationWithDescription("update article")

                        article1.summary = "Hello world!"

                        subject.batchSave([], articles: [article1]).then { _ in
                            expectation.fulfill()
                        }

                        self.waitForExpectationsWithTimeout(1, handler: nil)

                        expect(searchIndex.lastItemsAdded.count).to(equal(1))
                        if let item = searchIndex.lastItemsAdded.first as? CSSearchableItem {
                            let identifier = article1.identifier
                            expect(item.uniqueIdentifier).to(equal(identifier))
                            expect(item.domainIdentifier).to(beNil())
                            expect(item.expirationDate).to(equal(Date.distantFuture()))
                            let attributes = item.attributeSet
                            expect(attributes.contentType).to(equal(kUTTypeHTML as String))
                            expect(attributes.title).to(equal(article1.title))
                            let keywords = ["article"] + article1.feed!.title.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                            expect(attributes.keywords).to(equal(keywords))
                            expect(attributes.URL).to(equal(article1.link))
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
                    let expectation = self.expectationWithDescription("delete feed")

                    let articleIdentifiers = feed1.articlesArray.map { $0.identifier }

                    subject.deleteFeed(feed1).then {
                        guard case Result.success() = $0 else { return }
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    #if os(iOS)
                        expect(searchIndex.lastItemsDeleted) == articleIdentifiers
                    #endif

                    let feed = realm.objectForPrimaryKey(RealmFeed.self, key: feed1.feedID as! String)
                    expect(feed).to(beNil())
                }

                it("deletes articles") {
                    let expectation = self.expectationWithDescription("delete article")

                    subject.deleteArticle(article1).then {
                        guard case Result.success() = $0 else { return }
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)


                    #if os(iOS)
                        expect(searchIndex.lastItemsDeleted).to(contain(article1.identifier))
                    #endif

                    let article = realm.objectForPrimaryKey(RealmArticle.self, key: article1.articleID as! String)
                    expect(article).to(beNil())
                }
            }
        }

        dataServiceSharedSpec(subject, spec: self)
    }
}

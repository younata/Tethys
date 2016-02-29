import Quick
import Nimble
import RealmSwift
import Muon
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

        var subject = RealmService(realm: realm, mainQueue: mainQueue, searchIndex: searchIndex)

        beforeEach {
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            searchIndex = FakeSearchIndex()

            subject = RealmService(realm: realm, mainQueue: mainQueue, searchIndex: searchIndex)
        }

        describe("create operations") {
            it("new feed creates a new feed object") {
                let expectation = self.expectationWithDescription("Create Feed")

                subject.createFeed { feed in
                    feed.title = "Hello"
                    feed.url = NSURL(string: "https://example.com/feed")
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

            it("new enclosure creates a new enclosure object") {
                let expectation = self.expectationWithDescription("Create Enclosure")

                subject.createEnclosure(nil) { enclosure in
                    enclosure.kind = "hi"
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1, handler: nil)

                let enclosures = realm.objects(RealmEnclosure)
                expect(enclosures.count) == 1
                expect(enclosures.first?.kind) == "hi"
            }
        }

        describe("after creates") {
            var feed1: rNewsKit.Feed!
            var feed2: rNewsKit.Feed!
            var article1: rNewsKit.Article!
            var article2: rNewsKit.Article!
            var article3: rNewsKit.Article!
            var enclosure1: rNewsKit.Enclosure!
            var enclosure2: rNewsKit.Enclosure!

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
                realmArticle1.published = NSDate(timeIntervalSince1970: 15)
                realmArticle2.title = "article2"
                realmArticle2.published = NSDate(timeIntervalSince1970: 10)
                realmArticle3.title = "article3"
                realmArticle3.published = NSDate(timeIntervalSince1970: 5)
                realmArticle1.feed = realmFeed1
                realmArticle2.feed = realmFeed1
                realmArticle3.feed = realmFeed2

                realmArticle3.relatedArticles.append(realmArticle2)
                realmArticle2.relatedArticles.append(realmArticle3)

                let realmEnclosure1 = RealmEnclosure()
                let realmEnclosure2 = RealmEnclosure()

                realmEnclosure1.kind = "1"
                realmEnclosure2.kind = "2"
                realmEnclosure1.article = realmArticle1
                realmEnclosure2.article = realmArticle1

                for object in [realmFeed1, realmFeed2, realmArticle1, realmArticle2, realmArticle3, realmEnclosure1, realmEnclosure2] {
                    realm.add(object)
                }
                _ = try? realm.commitWrite()

                feed1 = Feed(realmFeed: realmFeed1)
                feed2 = Feed(realmFeed: realmFeed2)

                article1 = Article(realmArticle: realmArticle1, feed: feed1)
                article2 = Article(realmArticle: realmArticle2, feed: feed1)
                article3 = Article(realmArticle: realmArticle3, feed: feed2)

                enclosure1 = Enclosure(realmEnclosure: realmEnclosure1, article: article1)
                enclosure2 = Enclosure(realmEnclosure: realmEnclosure2, article: article1)
            }

            describe("read operations") {
                it("reads the feeds based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all feeds")
                    subject.feedsMatchingPredicate(NSPredicate(value: true)) {
                        expect($0) == [feed1, feed2]
                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectationWithDescription("Read some feeds")
                    subject.feedsMatchingPredicate(NSPredicate(format: "title == %@", "feed1")) {
                        expect($0) == [feed1]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }

                it("reads the articles based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all articles")
                    subject.articlesMatchingPredicate(NSPredicate(value: true)) { articles in
                        expect(articles) == [article1, article2, article3]

                        expect(articles[1].relatedArticles).to(contain(article3))
                        expect(articles[2].relatedArticles).to(contain(article2))

                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectationWithDescription("Read some articles")
                    subject.articlesMatchingPredicate(NSPredicate(format: "title == %@", "article1")) {
                        expect($0) == [article1]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }

                it("reads all enclosures based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all enclosures")
                    subject.enclosuresMatchingPredicate(NSPredicate(value: true)) {
                        expect($0) == [enclosure1, enclosure2]
                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectationWithDescription("Read some enclosures")
                    subject.enclosuresMatchingPredicate(NSPredicate(format: "kind == %@", "1")) {
                        expect($0) == [enclosure1]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }

            describe("update operations") {
                it("updates a feed") {
                    let expectation = self.expectationWithDescription("update feed")

                    feed1.summary = "hello world"

                    subject.saveFeed(feed1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let feed = realm.objectForPrimaryKey(RealmFeed.self, key: feed1.feedID as! String)
                    expect(feed).toNot(beNil())
                    expect(feed?.summary) == "hello world"
                }

                it("updates an article") {
                    let expectation = self.expectationWithDescription("update article")

                    article1.summary = "hello world"
                    article1.addRelatedArticle(article2)

                    subject.saveArticle(article1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let article = realm.objectForPrimaryKey(RealmArticle.self, key: article1.articleID as! String)
                    expect(article?.summary) == "hello world"
                    expect(article?.relatedArticles).toNot(beEmpty())
                }

                #if os(iOS)
                    if #available(iOS 9.0, *) {
                        it("should, on iOS 9, update the search index when an article is updated") {
                            let expectation = self.expectationWithDescription("update article")

                            article1.summary = "Hello world!"

                            subject.saveArticle(article1) {
                                expectation.fulfill()
                            }

                            self.waitForExpectationsWithTimeout(1, handler: nil)

                            expect(searchIndex.lastItemsAdded.count).to(equal(1))
                            if let item = searchIndex.lastItemsAdded.first as? CSSearchableItem {
                                let identifier = article1.identifier
                                expect(item.uniqueIdentifier).to(equal(identifier))
                                expect(item.domainIdentifier).to(beNil())
                                expect(item.expirationDate).to(equal(NSDate.distantFuture()))
                                let attributes = item.attributeSet
                                expect(attributes.contentType).to(equal(kUTTypeHTML as String))
                                expect(attributes.title).to(equal(article1.title))
                                let keywords = ["article"] + article1.feed!.title.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                                expect(attributes.keywords).to(equal(keywords))
                                expect(attributes.URL).to(equal(article1.link))
                                expect(attributes.timestamp).to(equal(article1.updatedAt ?? article1.published))
                                expect(attributes.authorNames).to(equal([article1.author]))
                                expect(attributes.contentDescription).to(equal("Hello world!"))
                            }
                        }
                    }
                #endif

                it("updates an enclosure") {
                    let expectation = self.expectationWithDescription("update enclosure")

                    enclosure1.kind = "3"

                    subject.saveEnclosure(enclosure1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let enclosures = realm.objects(RealmEnclosure).filter(NSPredicate(format: "id == %@", enclosure1.enclosureID as! String))
                    expect(enclosures.count) == 1
                    let enclosure = realm.objectForPrimaryKey(RealmEnclosure.self, key: enclosure1.enclosureID as! String)
                    expect(enclosure?.kind) == "3"
                }
            }

            describe("delete operations") {
                it("deletes feeds") {
                    let expectation = self.expectationWithDescription("delete feed")

                    let articleIdentifiers = feed1.articlesArray.map { $0.identifier }

                    subject.deleteFeed(feed1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    #if os(iOS)
                        if #available(iOS 9, *) {
                            expect(searchIndex.lastItemsDeleted) == articleIdentifiers
                        }
                    #endif

                    let feed = realm.objectForPrimaryKey(RealmFeed.self, key: feed1.feedID as! String)
                    expect(feed).to(beNil())
                }

                it("deletes articles") {
                    let expectation = self.expectationWithDescription("delete article")

                    subject.deleteArticle(article1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)


                    #if os(iOS)
                        if #available(iOS 9, *) {
                            expect(searchIndex.lastItemsDeleted).to(contain(article1.identifier))
                        }
                    #endif

                    let article = realm.objectForPrimaryKey(RealmArticle.self, key: article1.articleID as! String)
                    expect(article).to(beNil())
                }
                
                it("deletes enclosures") {
                    let expectation = self.expectationWithDescription("delete enclosure")
                    
                    subject.deleteEnclosure(enclosure1) {
                        expectation.fulfill()
                    }
                    
                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let enclosure = realm.objectForPrimaryKey(RealmEnclosure.self, key: enclosure1.enclosureID as! String)
                    expect(enclosure).to(beNil())
                }
            }
        }

        dataServiceSharedSpec(subject, spec: self)
    }
}

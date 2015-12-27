import Quick
import Nimble
import CoreData
import Muon
@testable import rNewsKit

private func coreDataEntities(entity: String,
    matchingPredicate predicate: NSPredicate,
    managedObjectContext: NSManagedObjectContext) -> [NSManagedObject] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName(entity,
            inManagedObjectContext: managedObjectContext)
        request.predicate = predicate

        var ret: [NSManagedObject]?

        managedObjectContext.performBlockAndWait {
            ret = try? managedObjectContext.executeFetchRequest(request) as? [NSManagedObject] ?? []
        }

        return ret ?? []
}

class CoreDataServiceSpec: QuickSpec {
    override func spec() {
        var subject: CoreDataService!
        var objectContext: NSManagedObjectContext!
        var mainQueue: FakeOperationQueue!

        beforeEach {
            objectContext = managedObjectContext()
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            subject = CoreDataService(managedObjectContext: objectContext, mainQueue: mainQueue)
        }

        describe("create operations") {
            it("new feed creates a new feed object") {
                let expectation = self.expectationWithDescription("Create Feed")

                subject.createFeed { feed in
                    feed.title = "Hello"
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1, handler: nil)

                let managedObjects = coreDataEntities("Feed", matchingPredicate: NSPredicate(value: true), managedObjectContext: objectContext)
                expect(managedObjects is [CoreDataFeed]) == true
                guard let feeds = managedObjects as? [CoreDataFeed] else { return }
                expect(feeds.count) == 1
                guard let feed = feeds.first else { return }
                expect(feed.title) == "Hello"
            }

            it("new article creates a new article object") {
                let expectation = self.expectationWithDescription("Create Article")

                subject.createArticle(nil) { article in
                    article.title = "Hello"
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1, handler: nil)

                let managedObjects = coreDataEntities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: objectContext)
                expect(managedObjects is [CoreDataArticle]) == true
                guard let articles = managedObjects as? [CoreDataArticle] else { return }
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

                let managedObjects = coreDataEntities("Enclosure", matchingPredicate: NSPredicate(value: true), managedObjectContext: objectContext)
                expect(managedObjects is [CoreDataEnclosure]) == true
                guard let enclosures = managedObjects as? [CoreDataEnclosure] else { return }
                expect(enclosures.count) == 1
                guard let enclosure = enclosures.first else { return }
                expect(enclosure.kind) == "hi"
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
                let feedDescription = NSEntityDescription.entityForName("Feed", inManagedObjectContext: objectContext)!
                let articleDescription = NSEntityDescription.entityForName("Article", inManagedObjectContext: objectContext)!
                let enclosureDescription = NSEntityDescription.entityForName("Enclosure", inManagedObjectContext: objectContext)!

                objectContext.performBlockAndWait {
                    let cdfeed1 = CoreDataFeed(entity: feedDescription, insertIntoManagedObjectContext: objectContext)
                    let cdfeed2 = CoreDataFeed(entity: feedDescription, insertIntoManagedObjectContext: objectContext)
                    cdfeed1.title = "feed1"
                    cdfeed2.title = "feed2"

                    let cdarticle1 = CoreDataArticle(entity: articleDescription, insertIntoManagedObjectContext: objectContext)
                    let cdarticle2 = CoreDataArticle(entity: articleDescription, insertIntoManagedObjectContext: objectContext)
                    let cdarticle3 = CoreDataArticle(entity: articleDescription, insertIntoManagedObjectContext: objectContext)

                    cdarticle1.title = "article1"
                    cdarticle1.published = NSDate(timeIntervalSince1970: 15)
                    cdarticle2.title = "article2"
                    cdarticle2.published = NSDate(timeIntervalSince1970: 10)
                    cdarticle3.title = "article3"
                    cdarticle3.published = NSDate(timeIntervalSince1970: 5)
                    cdarticle1.feed = cdfeed1
                    cdarticle2.feed = cdfeed1
                    cdarticle3.feed = cdfeed2

                    let cdenclosure1 = CoreDataEnclosure(entity: enclosureDescription, insertIntoManagedObjectContext: objectContext)
                    let cdenclosure2 = CoreDataEnclosure(entity: enclosureDescription, insertIntoManagedObjectContext: objectContext)

                    cdenclosure1.kind = "1"
                    cdenclosure2.kind = "2"
                    cdenclosure1.article = cdarticle1
                    cdenclosure2.article = cdarticle1

                    try! objectContext.save()

                    feed1 = Feed(feed: cdfeed1)
                    feed2 = Feed(feed: cdfeed2)

                    article1 = Article(article: cdarticle1, feed: feed1)
                    article2 = Article(article: cdarticle2, feed: feed1)
                    article3 = Article(article: cdarticle3, feed: feed2)

                    enclosure1 = Enclosure(enclosure: cdenclosure1, article: article1)
                    enclosure2 = Enclosure(enclosure: cdenclosure2, article: article1)

                }
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
                    subject.articlesMatchingPredicate(NSPredicate(value: true)) {
                        expect($0) == [article1, article2, article3]
                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectationWithDescription("Read some articles")
                    subject.articlesMatchingPredicate(NSPredicate(format: "feed == %@", feed1.feedID!)) {
                        expect($0) == [article1, article2]
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

                    let objects = coreDataEntities("Feed", matchingPredicate: NSPredicate(format: "SELF == %@", feed1.feedID!), managedObjectContext: objectContext) as! [CoreDataFeed]
                    let feed = objects.first!
                    expect(feed.summary) == "hello world"
                }

                it("updates an article") {
                    let expectation = self.expectationWithDescription("update article")

                    article1.summary = "hello world"

                    subject.saveArticle(article1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let objects = coreDataEntities("Article", matchingPredicate: NSPredicate(format: "SELF == %@", article1.articleID!), managedObjectContext: objectContext) as! [CoreDataArticle]
                    let article = objects.first!
                    expect(article.summary) == "hello world"
                }

                it("updates an enclosure") {
                    let expectation = self.expectationWithDescription("update enclosure")

                    enclosure1.kind = "3"

                    subject.saveEnclosure(enclosure1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let objects = coreDataEntities("Enclosure", matchingPredicate: NSPredicate(format: "SELF == %@", enclosure1.enclosureID!), managedObjectContext: objectContext) as! [CoreDataEnclosure]
                    let enclosure = objects.first!
                    expect(enclosure.kind) == "3"
                }
            }

            describe("delete operations") {
                it("deletes feeds") {
                    let expectation = self.expectationWithDescription("delete feed")

                    subject.deleteFeed(feed1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let feeds = coreDataEntities("Feed", matchingPredicate: NSPredicate(format: "SELF == %@", feed1.feedID!), managedObjectContext: objectContext)
                    expect(feeds).to(beEmpty())
                }

                it("deletes articles") {
                    let expectation = self.expectationWithDescription("delete article")

                    subject.deleteArticle(article1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let articles = coreDataEntities("Article", matchingPredicate: NSPredicate(format: "SELF == %@", article1.articleID!), managedObjectContext: objectContext)
                    expect(articles).to(beEmpty())
                }

                it("deletes enclosures") {
                    let expectation = self.expectationWithDescription("delete enclosure")

                    subject.deleteEnclosure(enclosure1) {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let enclosures = coreDataEntities("Enclosure", matchingPredicate: NSPredicate(format: "SELF == %@", enclosure1.enclosureID!), managedObjectContext: objectContext)
                    expect(enclosures).to(beEmpty())
                }
            }
        }

        describe("as a data service") {
            describe("feeds") {
                var feed: rNewsKit.Feed?

                beforeEach {
                    let createExpectation = self.expectationWithDescription("Create Feed")
                    subject.createFeed {
                        feed = $0
                        createExpectation.fulfill()
                    }
                    self.waitForExpectationsWithTimeout(1, handler: nil)
                    expect(feed).toNot(beNil())
                }

                afterEach {
                    if let feed = feed {
                        let deleteFeedExpectation = self.expectationWithDescription("Delete Feed")
                        subject.deleteFeed(feed) {
                            deleteFeedExpectation.fulfill()
                        }
                        self.waitForExpectationsWithTimeout(1, handler: nil)
                    }
                }

                it("easily allows a feed to be updated") {
                    guard let feed = feed else { fail(); return }
                    let info = Muon.Feed(title: "a title", link: NSURL(string: "https://google.com")!, description: "description", articles: [])
                    let updateExpectation = self.expectationWithDescription("Update Feed")
                    subject.updateFeed(feed, info: info) {
                        expect(feed.title) == "a title"
                        expect(feed.summary) == "description"
                        expect(feed.url).to(beNil())
                        updateExpectation.fulfill()
                    }
                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }

            describe("articles") {
                var article: rNewsKit.Article?

                beforeEach {
                    let createExpectation = self.expectationWithDescription("Create Article")
                    subject.createArticle(nil) {
                        article = $0
                        createExpectation.fulfill()
                    }
                    self.waitForExpectationsWithTimeout(1, handler: nil)
                    expect(article).toNot(beNil())
                }

                afterEach {
                    if let article = article {
                        let deleteExpectation = self.expectationWithDescription("Delete Article")
                        subject.deleteArticle(article) {
                            deleteExpectation.fulfill()
                        }
                        self.waitForExpectationsWithTimeout(1, handler: nil)
                    }
                }

                it("easily allows an article to be updated") {
                    guard let article = article else { fail(); return }
                    let author = Muon.Author(name: "Rachel Brindle", email: NSURL(string: "mailto:rachel@example.com"), uri: NSURL(string: "https://example.com/rachel"))
                    let item = Muon.Article(title: "a title", link: NSURL(string: "https://example.com"), description: "description", content: "content", guid: "guid", published: NSDate(timeIntervalSince1970: 10), updated: NSDate(timeIntervalSince1970: 15), authors: [author], enclosures: [])

                    let updateExpectation = self.expectationWithDescription("Update Article")
                    subject.updateArticle(article, item: item) {
                        expect(article.title) == "a title"
                        expect(article.link) == NSURL(string: "https://example.com")
                        expect(article.published) == NSDate(timeIntervalSince1970: 10)
                        expect(article.updatedAt) == NSDate(timeIntervalSince1970: 15)
                        expect(article.summary) == "description"
                        expect(article.content) == "content"
                        expect(article.author) == "Rachel Brindle <rachel@example.com>"
                        updateExpectation.fulfill()
                    }
                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }

                describe("updating enclosures") {
                    let muonEnclosure = Muon.Enclosure(url: NSURL(string: "https://example.com")!, length: 10, type: "html")
                    var enclosure: rNewsKit.Enclosure?

                    afterEach {
                        if let enclosure = enclosure {
                            let deleteExpectation = self.expectationWithDescription("Delete Enclosure")
                            subject.deleteEnclosure(enclosure) {
                                deleteExpectation.fulfill()
                            }
                            self.waitForExpectationsWithTimeout(1, handler: nil)
                        }
                    }

                    context("when the given article has an existing enclosure object matching the given one") {
                        beforeEach {
                            let createExpectation = self.expectationWithDescription("Create Enclosure")
                            subject.createEnclosure(nil) {
                                $0.url = NSURL(string: "https://example.com")!
                                $0.kind = "html"
                                article?.addEnclosure($0)
                                enclosure = $0
                                createExpectation.fulfill()
                            }
                            self.waitForExpectationsWithTimeout(1, handler: nil)
                            expect(enclosure).toNot(beNil())
                        }

                        it("essentially no-ops, and specifically does not add another enclosure to the article") {
                            guard let article = article else { fail(); return; }
                            let updateExpectation = self.expectationWithDescription("Update Enclosure")
                            subject.upsertEnclosureForArticle(article, fromItem: muonEnclosure) {
                                expect($0) == enclosure
                                updateExpectation.fulfill()
                            }

                            self.waitForExpectationsWithTimeout(1, handler: nil)

                            expect(article.enclosuresArray.count) == 1
                        }
                    }

                    context("when the given article does not have an existing enclosure object matching the given one") {
                        it("creates a new enclosure and inserts that into the article") {
                            guard let article = article else { fail(); return; }
                            let updateExpectation = self.expectationWithDescription("Update Enclosure")
                            subject.upsertEnclosureForArticle(article, fromItem: muonEnclosure) {
                                enclosure = $0
                                updateExpectation.fulfill()
                            }

                            self.waitForExpectationsWithTimeout(1, handler: nil)

                            let objects = coreDataEntities("Enclosure", matchingPredicate: NSPredicate(format: "self == %@", enclosure!.enclosureID!), managedObjectContext: objectContext) as? [CoreDataEnclosure]
                            expect(objects?.count) == 1
                            guard let cdenclosure = objects?.first else { return }
                            expect(cdenclosure.article).toNot(beNil())
                            expect(cdenclosure.url) == "https://example.com"
                            expect(cdenclosure.kind) == "html"
                        }
                    }
                }
            }
        }
    }
}

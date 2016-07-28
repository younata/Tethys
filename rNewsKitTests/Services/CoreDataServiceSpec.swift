import Quick
import Nimble
import CoreData
import Result
@testable import rNewsKit
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
#endif

func coreDataEntities(entity: String,
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
        var objectContext = managedObjectContext()
        var mainQueue = FakeOperationQueue()
        mainQueue.runSynchronously = true
        var searchIndex = FakeSearchIndex()
        var subject = CoreDataService(managedObjectContext: objectContext, mainQueue: mainQueue, searchIndex: searchIndex)

        beforeEach {
            objectContext = managedObjectContext()
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            searchIndex = FakeSearchIndex()
            subject = CoreDataService(managedObjectContext: objectContext, mainQueue: mainQueue, searchIndex: searchIndex)
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
                    cdarticle1.link = "https://example.com/article1"
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

                    feed1 = Feed(coreDataFeed: cdfeed1)
                    feed2 = Feed(coreDataFeed: cdfeed2)

                    article1 = Article(coreDataArticle: cdarticle1, feed: feed1)
                    article2 = Article(coreDataArticle: cdarticle2, feed: feed1)
                    article3 = Article(coreDataArticle: cdarticle3, feed: feed2)

                    _ = Enclosure(coreDataEnclosure: cdenclosure1, article: article1)
                    _ = Enclosure(coreDataEnclosure: cdenclosure2, article: article1)

                }
            }

            describe("read operations") {
                it("reads the feeds based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all feeds")
                    subject.allFeeds().then {
                        guard case let Result.Success(feeds) = $0 else { return }
                        expect(Array(feeds)) == [feed1, feed2]
                        allExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }

                it("reads the articles based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all articles")
                    subject.articlesMatchingPredicate(NSPredicate(value: true)).then {
                        guard case let Result.Success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1, article2, article3]
                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectationWithDescription("Read some articles")
                    subject.articlesMatchingPredicate(NSPredicate(format: "feed == %@", feed1.feedID as! NSManagedObjectID)).then {
                        guard case let Result.Success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1, article2]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }

            describe("delete operations") {
                it("deletes feeds") {
                    let expectation = self.expectationWithDescription("delete feed")

                    let articleIdentifiers = feed1.articlesArray.map { $0.identifier }

                    subject.deleteFeed(feed1).then {
                        guard case Result.Success() = $0 else { return }
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    #if os(iOS)
                        expect(searchIndex.lastItemsDeleted) == articleIdentifiers
                    #endif

                    let feeds = coreDataEntities("Feed", matchingPredicate: NSPredicate(format: "SELF == %@", feed1.feedID as! NSManagedObjectID), managedObjectContext: objectContext)
                    expect(feeds).to(beEmpty())
                }

                it("deletes articles") {
                    let expectation = self.expectationWithDescription("delete article")

                    subject.deleteArticle(article1).then {
                        guard case Result.Success() = $0 else { return }
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let articles = coreDataEntities("Article", matchingPredicate: NSPredicate(format: "SELF == %@", article1.articleID as! NSManagedObjectID), managedObjectContext: objectContext)

                    #if os(iOS)
                        expect(searchIndex.lastItemsDeleted).to(contain(article1.identifier))
                    #endif

                    expect(articles).to(beEmpty())
                }
            }
        }

        describe("As a data service") {
            dataServiceSharedSpec(subject, spec: self)
        }
    }
}

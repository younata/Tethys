import Quick
import Nimble
import CoreData
import Result
@testable import rNewsKit
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
#endif

func coreDataEntities(_ entity: String,
    matchingPredicate predicate: NSPredicate,
    managedObjectContext: NSManagedObjectContext) -> [NSManagedObject] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entity(forEntityName: entity,
            in: managedObjectContext)
        request.predicate = predicate

        var ret: [NSManagedObject]?

        managedObjectContext.performAndWait {
            ret = try? managedObjectContext.fetch(request) as? [NSManagedObject] ?? []
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
                let expectation = self.expectation(withDescription: "Create Feed")

                subject.createFeed { feed in
                    feed.title = "Hello"
                    expectation.fulfill()
                }

                self.waitForExpectations(withTimeout: 1, handler: nil)

                let managedObjects = coreDataEntities("Feed", matchingPredicate: NSPredicate(value: true), managedObjectContext: objectContext)
                expect(managedObjects is [CoreDataFeed]) == true
                guard let feeds = managedObjects as? [CoreDataFeed] else { return }
                expect(feeds.count) == 1
                guard let feed = feeds.first else { return }
                expect(feed.title) == "Hello"
            }

            it("new article creates a new article object") {
                let expectation = self.expectation(withDescription: "Create Article")

                subject.createArticle(nil) { article in
                    article.title = "Hello"
                    expectation.fulfill()
                }

                self.waitForExpectations(withTimeout: 1, handler: nil)

                let managedObjects = coreDataEntities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: objectContext)
                expect(managedObjects is [CoreDataArticle]) == true
                guard let articles = managedObjects as? [CoreDataArticle] else { return }
                expect(articles.count) == 1
                guard let article = articles.first else { return }
                expect(article.title) == "Hello"
            }
        }

        describe("after creates") {
            var feed1: rNewsKit.Feed!
            var feed2: rNewsKit.Feed!
            var article1: rNewsKit.Article!
            var article2: rNewsKit.Article!
            var article3: rNewsKit.Article!

            beforeEach {
                let feedDescription = NSEntityDescription.entity(forEntityName: "Feed", in: objectContext)!
                let articleDescription = NSEntityDescription.entity(forEntityName: "Article", in: objectContext)!

                objectContext.performAndWait {
                    let cdfeed1 = CoreDataFeed(entity: feedDescription, insertIntoManagedObjectContext: objectContext)
                    let cdfeed2 = CoreDataFeed(entity: feedDescription, insertIntoManagedObjectContext: objectContext)
                    cdfeed1.title = "feed1"
                    cdfeed1.url = ""
                    cdfeed2.title = "feed2"
                    cdfeed2.url = ""

                    let cdarticle1 = CoreDataArticle(entity: articleDescription, insertIntoManagedObjectContext: objectContext)
                    let cdarticle2 = CoreDataArticle(entity: articleDescription, insertIntoManagedObjectContext: objectContext)
                    let cdarticle3 = CoreDataArticle(entity: articleDescription, insertIntoManagedObjectContext: objectContext)

                    cdarticle1.title = "article1"
                    cdarticle1.link = "https://example.com/article1"
                    cdarticle1.published = Date(timeIntervalSince1970: 15)
                    cdarticle2.title = "article2"
                    cdarticle2.published = Date(timeIntervalSince1970: 10)
                    cdarticle3.title = "article3"
                    cdarticle3.published = Date(timeIntervalSince1970: 5)
                    cdarticle1.feed = cdfeed1
                    cdarticle2.feed = cdfeed1
                    cdarticle3.feed = cdfeed2

                    try! objectContext.save()

                    feed1 = Feed(coreDataFeed: cdfeed1)
                    feed2 = Feed(coreDataFeed: cdfeed2)

                    article1 = Article(coreDataArticle: cdarticle1, feed: feed1)
                    article2 = Article(coreDataArticle: cdarticle2, feed: feed1)
                    article3 = Article(coreDataArticle: cdarticle3, feed: feed2)
                }
            }

            describe("read operations") {
                it("reads the feeds based on the predicate") {
                    let allExpectation = self.expectation(withDescription: "Read all feeds")
                    subject.allFeeds().then {
                        guard case let Result.Success(feeds) = $0 else { return }
                        expect(Array(feeds)) == [feed1, feed2]
                        allExpectation.fulfill()
                    }

                    self.waitForExpectations(withTimeout: 1, handler: nil)
                }

                it("reads the articles based on the predicate") {
                    let allExpectation = self.expectation(withDescription: "Read all articles")
                    subject.articlesMatchingPredicate(NSPredicate(value: true)).then {
                        guard case let Result.Success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1, article2, article3]
                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectation(withDescription: "Read some articles")
                    subject.articlesMatchingPredicate(NSPredicate(format: "feed == %@", feed1.feedID as! NSManagedObjectID)).then {
                        guard case let Result.Success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1, article2]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectations(withTimeout: 1, handler: nil)
                }
            }

            describe("delete operations") {
                it("deletes feeds") {
                    let expectation = self.expectation(withDescription: "delete feed")

                    let articleIdentifiers = feed1.articlesArray.map { $0.identifier }

                    subject.deleteFeed(feed1).then {
                        guard case Result.Success() = $0 else { return }
                        expectation.fulfill()
                    }

                    self.waitForExpectations(withTimeout: 1, handler: nil)

                    #if os(iOS)
                        expect(searchIndex.lastItemsDeleted) == articleIdentifiers
                    #endif

                    let feeds = coreDataEntities("Feed", matchingPredicate: NSPredicate(format: "SELF == %@", feed1.feedID as! NSManagedObjectID), managedObjectContext: objectContext)
                    expect(feeds).to(beEmpty())
                }

                it("deletes articles") {
                    let expectation = self.expectation(withDescription: "delete article")

                    subject.deleteArticle(article1).then {
                        guard case Result.Success() = $0 else { return }
                        expectation.fulfill()
                    }

                    self.waitForExpectations(withTimeout: 1, handler: nil)

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

import Quick
import Nimble
@testable import rNewsKit
import Ra
import CoreData
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
#endif

private class FakeDataSubscriber: NSObject, DataSubscriber {
    private var markedArticles: [Article]? = nil
    private var read: Bool? = nil
    private func markedArticles(articles: [Article], asRead: Bool) {
        markedArticles = articles
        read = asRead
    }

    private var deletedArticle: Article? = nil
    private func deletedArticle(article: Article) {
        deletedArticle = article
    }

    private var deletedFeed: Feed? = nil
    private var deletedFeedsLeft: Int? = nil
    private func deletedFeed(feed: Feed, feedsLeft: Int) {
        deletedFeed = feed
        deletedFeedsLeft = feedsLeft
    }

    private var didStartUpdatingFeeds = false
    private func willUpdateFeeds() {
        didStartUpdatingFeeds = true
    }

    private var updateFeedsProgressFinished = 0
    private var updateFeedsProgressTotal = 0
    private func didUpdateFeedsProgress(finished: Int, total: Int) {
        updateFeedsProgressFinished = finished
        updateFeedsProgressTotal = total
    }


    private var updatedFeeds: [Feed]? = nil
    private func didUpdateFeeds(feeds: [Feed]) {
        updatedFeeds = feeds
    }
}

class FeedRepositorySpec: QuickSpec {
    override func spec() {
        var subject: DataRepository!

        var mainQueue: FakeOperationQueue!

        var feeds: [Feed] = []
        var feed1: Feed!
        var feed2: Feed!
        var feed3: Feed!

        var article1: Article!
        var article2: Article!

        var dataSubscriber: FakeDataSubscriber!

        var reachable: FakeReachable!

        var dataServiceFactory: FakeDataServiceFactory!
        var dataService: InMemoryDataService!

        var updateService: FakeUpdateService!

        var databaseMigrator: FakeDatabaseMigrator!

        beforeEach {
            feed1 = Feed(title: "a", url: NSURL(string: "https://example.com/feed1.feed"), summary: "",
                query: nil, tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            article1 = Article(title: "b", link: NSURL(string: "https://example.com/article1.html"),
                summary: "<p>Hello world!</p>", author: "", published: NSDate(), updatedAt: nil, identifier: "article1",
                content: "", read: false, estimatedReadingTime: 0, feed: feed1, flags: [], enclosures: [])

            article2 = Article(title: "c", link: NSURL(string: "https://example.com/article2.html"),
                summary: "<p>Hello world!</p>", author: "", published: NSDate(), updatedAt: nil, identifier: "article2",
                content: "", read: true, estimatedReadingTime: 0, feed: feed1, flags: [], enclosures: [])

            feed1.addArticle(article1)
            feed1.addArticle(article2)

            feed2 = Feed(title: "d", url: nil, summary: "", query: "function(article) {return true;}", tags: ["b", "d"],
                waitPeriod: 0, remainingWait: 0, articles: [article1, article2], image: nil)

            feed3 = Feed(title: "e", url: NSURL(string: "https://example.com/feed3.feed"), summary: "", query: nil,
                tags: ["dad"], waitPeriod: 0, remainingWait: 1, articles: [], image: nil)

            feeds = [feed1, feed2, feed3]

            reachable = FakeReachable(hasNetworkConnectivity: true)

            mainQueue = FakeOperationQueue()

            dataServiceFactory = FakeDataServiceFactory()
            dataService = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())
            dataServiceFactory.currentDataService = dataService

            dataService.feeds = feeds
            dataService.articles = [article1, article2]

            updateService = FakeUpdateService()

            databaseMigrator = FakeDatabaseMigrator()

            subject = DataRepository(mainQueue: mainQueue,
                reachable: reachable,
                dataServiceFactory: dataServiceFactory,
                updateService: updateService,
                databaseMigrator: databaseMigrator
            )

            dataSubscriber = FakeDataSubscriber()
            subject.addSubscriber(dataSubscriber)
        }

        afterEach {
            feeds = []
        }

        describe("databaseUpdateAvailable") {
            it("returns false by default") {
                expect(subject.databaseUpdateAvailable()) == false
            }

            context("when the user is using a CoreDataDataService") {
                it("returns true") {
                    let objectContext = managedObjectContext()
                    let mainQueue = FakeOperationQueue()
                    let searchIndex = FakeSearchIndex()
                    let coreDataService = CoreDataService(managedObjectContext: objectContext, mainQueue: mainQueue, searchIndex: searchIndex)
                    dataServiceFactory.currentDataService = coreDataService

                    expect(subject.databaseUpdateAvailable()) == true
                }
            }
        }

        describe("performing database migrations") {
            context("from Core Data to Realm") {
                var objectContext: NSManagedObjectContext!
                var mainQueue: FakeOperationQueue!
                var searchIndex: FakeSearchIndex!
                var coreDataService: CoreDataService!

                var migrationFinished = false

                var newDataService: InMemoryDataService!

                var progressUpdates: [Double] = []

                beforeEach {
                    objectContext = managedObjectContext()
                    mainQueue = FakeOperationQueue()
                    searchIndex = FakeSearchIndex()
                    coreDataService = CoreDataService(managedObjectContext: objectContext, mainQueue: mainQueue, searchIndex: searchIndex)
                    dataServiceFactory.currentDataService = coreDataService

                    newDataService = InMemoryDataService(mainQueue: mainQueue, searchIndex: searchIndex)
                    dataServiceFactory.newDataServiceReturns(newDataService)

                    progressUpdates = []
                    migrationFinished = false

                    subject.performDatabaseUpdates({ progressUpdates.append($0) }) {
                        migrationFinished = true
                    }
                }

                it("asks the dataServiceFactory for a new data service") {
                    expect(dataServiceFactory.newDataServiceCallCount) == 1
                }

                it("asks the migrator to migrate") {
                    expect(databaseMigrator.migrateCallCount) == 1

                    expect(databaseMigrator.migrateArgsForCall(0).0 as? CoreDataService) === coreDataService
                    expect(databaseMigrator.migrateArgsForCall(0).1 as? InMemoryDataService) === newDataService
                }

                context("when the migration finishes") {
                    beforeEach {
                        databaseMigrator.migrateArgsForCall(0).2()
                    }

                    it("sets the new data service as the current data service") {
                        expect(try! dataServiceFactory.setCurrentDataServiceArgsForCall(2) as? InMemoryDataService) === newDataService
                    }

                    it("deletes everything in the old dataService") {
                        expect(databaseMigrator.deleteEverythingCallCount) == 1
                        expect(databaseMigrator.deleteEverythingArgsForCall(0).0 as? CoreDataService) === coreDataService
                    }

                    context("when the deletion finishes") {
                        it("calls the callback") {
                            databaseMigrator.deleteEverythingArgsForCall(0).1()

                            expect(migrationFinished) == true
                        }
                    }
                }
            }
        }

        describe("as a DataRetriever") {
            describe("allTags") {
                var calledHandler = false
                var tags: [String] = []

                beforeEach {
                    calledHandler = false

                    subject.allTags {
                        calledHandler = true
                        tags = $0
                    }
                }

                it("should return a list of all tags") {
                    expect(calledHandler) == true
                    expect(tags).to(equal(["a", "b", "c", "d", "dad"]))
                }
            }

            describe("feeds") {
                var calledHandler = false
                var calledFeeds: [Feed] = []

                beforeEach {
                    calledHandler = false

                    subject.feeds {
                        calledHandler = true
                        calledFeeds = $0
                    }
                }

                it("should return the list of all feeds") {
                    expect(calledHandler) == true
                    expect(calledFeeds).to(equal(feeds))
                    for (idx, feed) in feeds.enumerate() {
                        let calledFeed = calledFeeds[idx]
                        expect(calledFeed.articlesArray == feed.articlesArray) == true
                    }
                }
            }

            describe("feedsMatchingTag:") {
                var calledHandler = false
                var calledFeeds: [Feed] = []

                beforeEach {
                    calledHandler = false
                }

                context("without a tag") {
                    it("should return all the feeds when nil tag is given") {
                        subject.feedsMatchingTag(nil) {
                            calledHandler = true
                            calledFeeds = $0
                        }

                        expect(calledHandler) == true
                        expect(calledFeeds).to(equal(feeds))
                    }

                    it("should return all the feeds when empty string is given as the tag") {
                        subject.feedsMatchingTag("") {
                            calledHandler = true
                            calledFeeds = $0
                        }
                        expect(calledFeeds).to(equal(feeds))
                    }
                }

                it("should return feeds that partially match a tag") {
                    subject.feedsMatchingTag("a") {
                        calledHandler = true
                        calledFeeds = $0
                    }
                    expect(calledFeeds) == [feed1, feed3]
                }
            }

            describe("articlesOfFeeds:MatchingSearchQuery:callback:") {
                var calledHandler = false
                var calledArticles = DataStoreBackedArray<Article>()

                beforeEach {
                    calledHandler = false
                    calledArticles = DataStoreBackedArray<Article>()

                    subject.articlesOfFeeds(feeds, matchingSearchQuery: "b") { articles in
                        calledHandler = true
                        calledArticles = articles
                    }
                }

                it("should return all articles that match the given search query") {
                    expect(mainQueue.operationCount).to(equal(1))

                    expect(calledHandler) == false

                    mainQueue.runNextOperation()

                    expect(mainQueue.operationCount).to(equal(0))
                    expect(calledHandler) == true
                    expect(Array(calledArticles)) == [article1]
                }
            }

            describe("articlesMatchingQuery") {
                var calledHandler = false
                var calledArticles: [Article] = []

                beforeEach {
                    calledHandler = false

                    subject.articlesMatchingQuery("function(article) {return !article.read;}") {
                        calledHandler = true
                        calledArticles = $0
                    }
                }

                it("should execute the javascript query upon all articles to compile thes query feed") {
                    expect(mainQueue.operationCount).to(equal(1))

                    expect(calledHandler) == false

                    mainQueue.runNextOperation()

                    expect(mainQueue.operationCount).to(equal(0))
                    expect(calledHandler) == true
                    expect(calledArticles) == [article1]
                }
            }
        }

        describe("as a DataWriter") {
            describe("newFeed") {
                var createdFeed: Feed? = nil
                beforeEach {
                    subject.newFeed {feed in
                        createdFeed = feed
                    }
                }

                it("should call back with a created feed") {
                    expect(dataService.feeds).to(contain(createdFeed))
                    expect(dataService.feeds.count) == 4
                }
            }

            describe("deleteFeed") {
                beforeEach {
                    mainQueue.runSynchronously = true
                    subject.deleteFeed(feed1)
                }

                it("should remove the feed from the data service") {
                    expect(dataService.feeds).toNot(contain(feed1))
                }

                it("should inform any subscribers") {
                    expect(dataSubscriber.deletedFeed).to(equal(feed1))
                    expect(dataSubscriber.deletedFeedsLeft).to(equal(2))
                }
            }

            describe("markFeedAsRead") {
                beforeEach {
                    subject.markFeedAsRead(feed1)
                }

                it("should mark every article in the feed as read") {
                    for article in feed1.articlesArray {
                        expect(article.read) == true
                    }
                }

                it("should inform any subscribers") {
                    expect(dataSubscriber.markedArticles).toNot(beNil())
                    expect(dataSubscriber.read) == true
                }
            }

            describe("saveArticle") {
                var article: Article! = nil
                var image: Image! = nil

                beforeEach {
                    let bundle = NSBundle(forClass: self.classForCoder)
                    let imageData = NSData(contentsOfURL: bundle.URLForResource("test", withExtension: "jpg")!)
                    image = Image(data: imageData!)

                    article = article1
                    article.feed?.image = image

                    article.title = "hello"
                    subject.saveArticle(article)
                }

                it("should update the data service") {
                    let updatedArticle = dataService.articles.filter { $0.title == "hello" }.first
                    expect(updatedArticle).toNot(beNil())
                    expect(article).to(equal(updatedArticle))
                    expect(article1).to(equal(updatedArticle))
                }
            }

            describe("deleteArticle") {
                var article: Article! = nil

                beforeEach {
                    article = article1

                    subject.deleteArticle(article)
                }

                it("should remove the article from the data service") {
                    expect(dataService.articles).toNot(contain(article))
                }

                it("should inform any subscribes") {
                    expect(dataSubscriber.deletedArticle).to(equal(article))
                }
            }

            describe("markArticle:asRead:") {
                var article: Article! = nil

                beforeEach {
                    article = article1

                    subject.markArticle(article, asRead: true)
                }

                it("should mark the article object as read") {
                    expect(article.read) == true
                }

                it("should inform any subscribers") {
                    expect(dataSubscriber.markedArticles).to(equal([article]))
                    expect(dataSubscriber.read) == true
                }

                describe("and marking it as unread again") {
                    beforeEach {
                        dataSubscriber.markedArticles = nil
                        dataSubscriber.read = nil
                        subject.markArticle(article, asRead: false)
                    }

                    it("should inform any subscribers") {
                        expect(dataSubscriber.markedArticles).to(equal([article]))
                        expect(dataSubscriber.read) == false
                    }
                }
            }

            describe("updateFeed:callback:") {
                var didCallCallback = false
                var callbackError: NSError? = nil
                var feed: Feed! = nil

                beforeEach {
                    didCallCallback = false
                    callbackError = nil

                    feed = feed1
                }

                context("when the network is not reachable") {
                    var updatedFeed: Feed? = nil
                    beforeEach {
                        reachable.hasNetworkConnectivity = false

                        subject.updateFeed(feed) {changedFeed, error in
                            didCallCallback = true
                            updatedFeed = changedFeed
                            callbackError = error
                        }
                    }

                    it("should not inform any subscribers") {
                        expect(dataSubscriber.didStartUpdatingFeeds) == false
                    }

                    it("should not make an update request") {
                        expect(updateService.updatedFeed).to(beNil())
                    }

                    it("should call the completion handler without an error and with the original feed") {
                        expect(didCallCallback) == true
                        expect(callbackError).to(beNil())
                        expect(updatedFeed).to(equal(feed))
                    }
                }

                context("when the network is reachable") {
                    beforeEach {
                        subject.updateFeed(feed) {changedFeed, error in
                            didCallCallback = true
                            callbackError = error
                        }
                    }

                    it("should inform any subscribers") {
                        expect(dataSubscriber.didStartUpdatingFeeds) == true
                    }

                    it("should make a network request for the feed if it has a remaniing wait of 0") {
                        expect(updateService.updatedFeed) == feed
                    }

                    context("when the network request succeeds") {
                        beforeEach {
                            expect(updateService.updatedFeedCallback).toNot(beNil())
                            updateService.updatedFeedCallback?(feed, nil)
                            mainQueue.runNextOperation()
                        }

                        it("should inform subscribers that we downloaded a thing and are about to process it") {
                            expect(dataSubscriber.updateFeedsProgressFinished).to(equal(1))
                            expect(dataSubscriber.updateFeedsProgressTotal).to(equal(1))
                        }

                        describe("when the last operation completes") {
                            beforeEach {
                                mainQueue.runNextOperation()
                                mainQueue.runNextOperation()
                            }

                            it("should inform subscribers that we updated our datastore for that feed") {
                                expect(dataSubscriber.updatedFeeds) == feeds
                            }

                            it("should call the completion handler without an error") {
                                expect(didCallCallback) == true
                                expect(callbackError).to(beNil())
                            }
                        }
                    }
                }
            }

            describe("updateFeeds:") {
                var didCallCallback = false
                var callbackErrors: [NSError] = []
                beforeEach {
                    didCallCallback = false
                    callbackErrors = []
                }

                context("when there are no feeds in the data store") {
                    beforeEach {
                        dataService.feeds = []
                        subject.updateFeeds {feeds, errors in
                            didCallCallback = true
                            callbackErrors = errors
                        }
                    }

                    it("should not inform any subscribers") {
                        expect(dataSubscriber.didStartUpdatingFeeds) == false
                    }

                    it("should call the callback with no errors") {
                        expect(didCallCallback) == true
                        expect(callbackErrors).to(beEmpty())
                    }

                    it("should not inform any subscribers") {
                        expect(dataSubscriber.updatedFeeds).to(beNil())
                    }
                }

                context("when the network is not reachable") {
                    beforeEach {
                        reachable.hasNetworkConnectivity = false

                        didCallCallback = false
                        callbackErrors = []
                        subject.updateFeeds {feeds, errors in
                            didCallCallback = true
                            callbackErrors = errors
                        }
                    }

                    it("should not inform any subscribers") {
                        expect(dataSubscriber.didStartUpdatingFeeds) == false
                    }

                    it("should not make a network request for every feed in the data store w/ a url and a remaining wait of 0") {
                        expect(updateService.updatedFeed).to(beNil())
                    }

                    it("should not decrement the remainingWait of every feed that did have a remaining wait of > 0") {
                        expect(feed3.remainingWait) == 1
                    }

                    it("should inform subscribers that we finished updating") {
                        expect(dataSubscriber.updateFeedsProgressFinished).to(equal(0))
                        expect(dataSubscriber.updateFeedsProgressTotal).to(equal(0))
                    }

                    it("should call the completion handler without an error") {
                        expect(didCallCallback) == true
                        expect(callbackErrors).to(equal([]))
                    }

                    it("should not inform any subscribers") {
                        expect(dataSubscriber.updatedFeeds).to(beNil())
                    }
                }

                context("when there are feeds in the data story") {
                    beforeEach {
                        didCallCallback = false
                        callbackErrors = []
                        subject.updateFeeds {feeds, errors in
                            didCallCallback = true
                            callbackErrors = errors
                        }
                    }

                    it("should inform any subscribers") {
                        expect(dataSubscriber.didStartUpdatingFeeds) == true
                    }

                    it("should make a network request for every feed in the data store w/ a url and a remaining wait of 0") {
                        expect(updateService.updatedFeed) == feed1
                    }

                    it("should decrement the remainingWait of every feed that did have a remaining wait of > 0") {
                        expect(feed3.remainingWait) == 0
                    }

                    context("trying to update feeds while a request is still in progress") {
                        var didCallUpdateCallback = false

                        beforeEach {
                            updateService.updatedFeed = nil
                            dataSubscriber.didStartUpdatingFeeds = false

                            subject.updateFeeds {feeds, errors in
                                didCallUpdateCallback = true
                            }
                        }

                        it("should not inform any subscribers") {
                            expect(dataSubscriber.didStartUpdatingFeeds) == false
                        }

                        it("should not make any update requests") {
                            expect(updateService.updatedFeed).to(beNil())
                        }

                        it("should not immediately call the callback") {
                            expect(didCallUpdateCallback) == false
                        }

                        context("when the original update request finishes") {
                            beforeEach {
                                mainQueue.runSynchronously = true
                                updateService.updatedFeedCallback?(feed1, nil)
                            }

                            it("should call both completion handlers") {
                                expect(didCallCallback) == true
                                expect(callbackErrors).to(equal([]))
                                expect(didCallUpdateCallback) == true
                            }
                        }
                    }

                    context("when the update request succeeds") {
                        beforeEach {
                            mainQueue.runSynchronously = true
                            updateService.updatedFeedCallback?(feed1, nil)
                        }

                        it("should inform subscribers that we downloaded a thing and are about to process it") {
                            expect(dataSubscriber.updateFeedsProgressFinished).to(equal(1))
                            expect(dataSubscriber.updateFeedsProgressTotal).to(equal(1))
                        }

                        it("should call the completion handler without an error") {
                            expect(didCallCallback) == true
                            expect(callbackErrors).to(equal([]))
                        }

                        it("should inform any subscribers") {
                            expect(dataSubscriber.updatedFeeds).toNot(beNil())
                        }
                    }
                }
            }
        }
    }
}

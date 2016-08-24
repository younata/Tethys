import Quick
import Nimble
@testable import rNewsKit
import Ra
import CoreData
import CBGPromise
import Result
import Sinope
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
#endif

class DefaultDatabaseUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultDatabaseUseCase!

        var mainQueue: FakeOperationQueue!

        var feeds: [rNewsKit.Feed] = []
        var feed1: rNewsKit.Feed!
        var feed2: rNewsKit.Feed!
        var feed3: rNewsKit.Feed!

        var article1: rNewsKit.Article!
        var article2: rNewsKit.Article!

        var dataSubscriber: FakeDataSubscriber!

        var reachable: FakeReachable!

        var dataServiceFactory: FakeDataServiceFactory!
        var dataService: InMemoryDataService!

        var updateUseCase: FakeUpdateUseCase!

        var databaseMigrator: FakeDatabaseMigrator!
        var accountRepository: FakeAccountRepository!
        var sinopeRepository: FakeSinopeRepository!

        beforeEach {
            feed1 = rNewsKit.Feed(title: "a", url: NSURL(string: "https://example.com/feed1.feed"), summary: "",
                query: nil, tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            article1 = rNewsKit.Article(title: "b", link: NSURL(string: "https://example.com/article1.html"),
                summary: "<p>Hello world!</p>", authors: [], published: NSDate(), updatedAt: nil, identifier: "article1",
                content: "", read: false, estimatedReadingTime: 0, feed: feed1, flags: [])

            article2 = rNewsKit.Article(title: "c", link: NSURL(string: "https://example.com/article2.html"),
                summary: "<p>Hello world!</p>", authors: [], published: NSDate(), updatedAt: nil, identifier: "article2",
                content: "", read: true, estimatedReadingTime: 0, feed: feed1, flags: [])

            feed1.addArticle(article1)
            feed1.addArticle(article2)

            feed2 = rNewsKit.Feed(title: "d", url: nil, summary: "", query: "function(article) {return true;}", tags: ["b", "d"],
                waitPeriod: 0, remainingWait: 0, articles: [article1, article2], image: nil)

            feed3 = rNewsKit.Feed(title: "e", url: NSURL(string: "https://example.com/feed3.feed"), summary: "", query: nil,
                tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            feeds = [feed1, feed2, feed3]

            reachable = FakeReachable(hasNetworkConnectivity: true)

            mainQueue = FakeOperationQueue()

            dataServiceFactory = FakeDataServiceFactory()
            dataService = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())
            dataServiceFactory.currentDataService = dataService

            dataService.feeds = feeds
            dataService.articles = [article1, article2]

            updateUseCase = FakeUpdateUseCase()

            databaseMigrator = FakeDatabaseMigrator()

            accountRepository = FakeAccountRepository()
            sinopeRepository = FakeSinopeRepository()

            accountRepository.loggedInReturns("foo@example.com")
            accountRepository.backendRepositoryReturns(sinopeRepository)

            subject = DefaultDatabaseUseCase(mainQueue: mainQueue,
                reachable: reachable,
                dataServiceFactory: dataServiceFactory,
                updateUseCase: updateUseCase,
                databaseMigrator: databaseMigrator,
                scriptService: JavaScriptService(),
                accountRepository: accountRepository
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
                        databaseMigrator.migrateArgsForCall(0).3()
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
                            databaseMigrator.deleteEverythingArgsForCall(0).2()

                            expect(migrationFinished) == true
                        }
                    }
                }
            }
        }

        describe("as a DataRetriever") {
            describe("allTags") {
                var calledHandler = false
                var calledResults: Result<[String], RNewsError>?

                beforeEach {
                    calledHandler = false

                    subject.allTags().then {
                        calledHandler = true
                        calledResults = $0
                    }
                }

                it("should return a list of all tags") {
                    expect(calledHandler) == true
                    expect(calledResults).toNot(beNil())
                    switch calledResults! {
                    case let .Success(tags):
                        expect(tags) == ["a", "b", "c", "d", "dad"]
                    case .Failure(_):
                        expect(false) == true
                    }

                }
            }

            describe("feeds") {
                var calledHandler = false
                var calledResults: Result<[rNewsKit.Feed], RNewsError>?

                beforeEach {
                    calledHandler = false

                    subject.feeds().then {
                        calledHandler = true
                        calledResults = $0
                    }
                }

                it("returns the list of all feeds") {
                    expect(calledHandler) == true
                    expect(calledResults).toNot(beNil())
                    switch calledResults! {
                    case let .Success(receivedFeeds):
                        expect(receivedFeeds) == feeds
                        for (idx, feed) in feeds.enumerate() {
                            let receivedFeed = receivedFeeds[idx]
                            expect(receivedFeed.articlesArray == feed.articlesArray) == true
                        }
                    case .Failure(_):
                        expect(false) == true
                    }
                }
            }

            describe("articlesOfFeed:MatchingSearchQuery:callback:") {
                it("should return all articles that match the given search query") {
                    let searchedArticles = subject.articlesOfFeed(feeds[0], matchingSearchQuery: "b")
                    expect(Array(searchedArticles)) == [article1]
                }
            }

            describe("articlesMatchingQuery") {
                var calledHandler = false
                var calledResults: Result<[rNewsKit.Article], RNewsError>? = nil

                beforeEach {
                    calledHandler = false

                    subject.articlesMatchingQuery("function(article) {return !article.read;}").then {
                        calledHandler = true
                        calledResults = $0
                    }
                }

                it("should execute the javascript query upon all articles to compile the query feed") {
                    expect(calledHandler) == true
                    expect(calledResults).toNot(beNil())
                    switch calledResults! {
                    case let .Success(articles):
                        expect(articles) == [article1]
                    case .Failure(_):
                        expect(false) == true
                    }
                }
            }
        }

        describe("as a DataWriter") {
            describe("newFeed") {
                var createdFeed: rNewsKit.Feed? = nil
                var subscribePromise: Promise<Result<[NSURL], SinopeError>>!
                var newFeedFuture: Future<Result<Void, RNewsError>>!

                describe("and the user makes a standard feed") {
                    beforeEach {
                        subscribePromise = Promise<Result<[NSURL], SinopeError>>()
                        sinopeRepository.subscribeReturns(subscribePromise.future)
                        newFeedFuture = subject.newFeed {feed in
                            feed.url = NSURL(string: "https://example.com/feed")
                            createdFeed = feed
                        }
                    }

                    it("should call back with a created feed") {
                        expect(dataService.feeds).to(contain(createdFeed))
                        expect(dataService.feeds.count) == 4
                    }

                    it("tells the sinope repository to subscribe to this feed") {
                        expect(sinopeRepository.subscribeCallCount) == 1
                        guard sinopeRepository.subscribeCallCount == 1 else { return }
                        let urls = sinopeRepository.subscribeArgsForCall(0)
                        expect(urls) == [NSURL(string: "https://example.com/feed")!]
                    }

                    it("resolves the future when the sinope repository finishes") {
                        expect(newFeedFuture.value).to(beNil())

                        subscribePromise.resolve(.Success([]))

                        expect(newFeedFuture.value?.value).toNot(beNil())
                    }
                }

                describe("and the user does not assign a url to the created feed") {
                    beforeEach {
                        newFeedFuture = subject.newFeed {feed in
                            createdFeed = feed
                        }
                    }

                    it("should call back with a created feed") {
                        expect(dataService.feeds).to(contain(createdFeed))
                        expect(dataService.feeds.count) == 4
                    }

                    it("does not tell the pasiphae repository to subscribe to this feed") {
                        expect(sinopeRepository.subscribeCallCount) == 0
                    }

                    it("resolves the future") {
                        expect(newFeedFuture.value?.value).toNot(beNil())
                    }
                }
            }

            describe("deleteFeed") {
                describe("deleting a standard feed") {
                    var unsubscribePromise: Promise<Result<[NSURL], SinopeError>>!
                    beforeEach {
                        unsubscribePromise = Promise<Result<[NSURL], SinopeError>>()
                        sinopeRepository.unsubscribeReturns(unsubscribePromise.future)

                        mainQueue.runSynchronously = true
                        subject.deleteFeed(feed1)
                    }

                    it("should remove the feed from the data service") {
                        expect(dataService.feeds).toNot(contain(feed1))
                    }

                    it("tells the pasiphae repository to unsubscribe from the feed") {
                        expect(sinopeRepository.unsubscribeCallCount) == 1
                        guard sinopeRepository.unsubscribeCallCount == 1 else { return }
                        let urls = sinopeRepository.unsubscribeArgsForCall(0)
                        expect(urls) == [NSURL(string: "https://example.com/feed1.feed")!]
                    }

                    it("does not inform any subscribers") {
                        expect(dataSubscriber.deletedFeed).to(beNil())
                        expect(dataSubscriber.deletedFeedsLeft).to(beNil())
                    }

                    describe("when the unsubscribe promise resolves") {
                        beforeEach {
                            unsubscribePromise.resolve(.Success([]))
                        }

                        it("should inform any subscribers") {
                            expect(dataSubscriber.deletedFeed).to(equal(feed1))
                            expect(dataSubscriber.deletedFeedsLeft).to(equal(2))
                        }
                    }
                }

                describe("deleting a query feed") {
                    beforeEach {
                        mainQueue.runSynchronously = true
                        subject.deleteFeed(feed2)
                    }

                    it("should remove the feed from the data service") {
                        expect(dataService.feeds).toNot(contain(feed2))
                    }

                    it("does not tell the pasiphae repository to unsubscribe from the feed") {
                        expect(sinopeRepository.unsubscribeCallCount) == 0
                    }

                    it("should inform any subscribers") {
                        expect(dataSubscriber.deletedFeed).to(equal(feed2))
                        expect(dataSubscriber.deletedFeedsLeft).to(equal(2))
                    }
                }
            }

            describe("markFeedAsRead") {
                var markedReadFuture: Future<Result<Int, RNewsError>>?
                beforeEach {
                    markedReadFuture = subject.markFeedAsRead(feed1)
                }

                it("marks every article in the feed as read") {
                    for article in feed1.articlesArray {
                        expect(article.read) == true
                    }
                }

                it("informs any subscribers") {
                    expect(dataSubscriber.markedArticles).toNot(beNil())
                    expect(dataSubscriber.read) == true
                }

                it("resolves the promise with the number of articles marked read") {
                    expect(markedReadFuture?.value).toNot(beNil())
                    let calledResults = markedReadFuture!.value!
                    switch calledResults {
                    case let .Success(value):
                        expect(value) == 1
                    case .Failure(_):
                        expect(false) == true
                    }
                }
            }

            describe("saveArticle") {
                var article: rNewsKit.Article! = nil
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
                var article: rNewsKit.Article! = nil

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
                var article: rNewsKit.Article! = nil

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
                var feed: rNewsKit.Feed! = nil

                var updateFeedsPromise: Promise<Result<Void, RNewsError>>!

                beforeEach {
                    didCallCallback = false
                    callbackError = nil

                    feed = feed1

                    updateFeedsPromise = Promise<Result<Void, RNewsError>>()
                    updateUseCase.updateFeedsReturns(updateFeedsPromise.future)
                }

                context("when the network is not reachable") {
                    var updatedFeed: rNewsKit.Feed? = nil
                    beforeEach {
                        reachable.hasNetworkConnectivity = false

                        subject.updateFeed(feed) {changedFeed, error in
                            didCallCallback = true
                            updatedFeed = changedFeed
                            callbackError = error
                        }
                    }

                    it("should not make an update request") {
                        expect(updateUseCase.updateFeedsCallCount) == 0
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

                    it("should make a request to update the feed") {
                        expect(updateUseCase.updateFeedsCallCount) == 1
                        guard updateUseCase.updateFeedsCallCount == 1 else { return }
                        let args = updateUseCase.updateFeedsArgsForCall(0)
                        expect(args.0) == [feed]
                        expect(args.1 as? [FakeDataSubscriber]) == [dataSubscriber]
                    }

                    context("when the network request succeeds") {
                        beforeEach {
                            updateFeedsPromise.resolve(.Success())
                            mainQueue.runNextOperation()
                        }

                        describe("when the last operation completes") {
                            beforeEach {
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

                var updateFeedsPromise: Promise<Result<Void, RNewsError>>!

                beforeEach {
                    didCallCallback = false
                    callbackErrors = []

                    updateFeedsPromise = Promise<Result<Void, RNewsError>>()
                    updateUseCase.updateFeedsReturns(updateFeedsPromise.future)
                }

                context("when there are no feeds in the data store") {
                    beforeEach {
                        dataService.feeds = []
                        subject.updateFeeds {feeds, errors in
                            didCallCallback = true
                            callbackErrors = errors
                        }
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

                    it("should not make any network requests") {
                        expect(updateUseCase.updateFeedsCallCount) == 0
                    }

                    it("should call the completion handler without an error") {
                        expect(didCallCallback) == true
                        expect(callbackErrors).to(equal([]))
                    }

                    it("should not inform any subscribers") {
                        expect(dataSubscriber.updatedFeeds).to(beNil())
                    }
                }

                context("when there are feeds in the data store") {
                    beforeEach {
                        didCallCallback = false
                        callbackErrors = []
                        subject.updateFeeds {feeds, errors in
                            didCallCallback = true
                            callbackErrors = errors
                        }
                    }

                    it("makes a feeds update for every feed in the data store w/ a url") {
                        expect(updateUseCase.updateFeedsCallCount) == 1
                        guard updateUseCase.updateFeedsCallCount == 1 else { return }
                        let args = updateUseCase.updateFeedsArgsForCall(0)
                        expect(args.0) == [feed1, feed3]
                        expect(args.1 as? [FakeDataSubscriber]) == [dataSubscriber]
                    }

                    context("trying to update feeds while a request is still in progress") {
                        var didCallUpdateCallback = false

                        beforeEach {
                            subject.updateFeeds {feeds, errors in
                                didCallUpdateCallback = true
                            }
                        }
                        it("should not make any update requests") {
                            expect(updateUseCase.updateFeedsCallCount) == 1
                        }

                        it("should not immediately call the callback") {
                            expect(didCallUpdateCallback) == false
                        }

                        context("when the original update request finishes") {
                            beforeEach {
                                mainQueue.runSynchronously = true
                                updateFeedsPromise.resolve(.Success())
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
                            updateFeedsPromise.resolve(.Success())
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

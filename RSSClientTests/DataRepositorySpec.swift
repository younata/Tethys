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
        var subject: DataRepository! = nil

        var mainQueue: FakeOperationQueue! = nil
        var backgroundQueue: FakeOperationQueue! = nil

        var feeds: [Feed] = []
        var feed1: Feed! = nil
        var feed2: Feed! = nil
        var feed3: Feed! = nil

        var article1: Article! = nil
        var article2: Article! = nil

        var dataSubscriber: FakeDataSubscriber! = nil

        var reachable: FakeReachable! = nil

        var dataService: InMemoryDataService! = nil

        var updateService: FakeUpdateService! = nil

        beforeEach {
            feed1 = Feed(title: "a", url: NSURL(string: "https://example.com/feed1.feed"), summary: "",
                query: nil, tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            article1 = Article(title: "b", link: NSURL(string: "https://example.com/article1.html"),
                summary: "<p>Hello world!</p>", author: "", published: NSDate(), updatedAt: nil, identifier: "article1",
                content: "", read: false, feed: feed1, flags: [], enclosures: [])

            article2 = Article(title: "c", link: NSURL(string: "https://example.com/article2.html"),
                summary: "<p>Hello world!</p>", author: "", published: NSDate(), updatedAt: nil, identifier: "article2",
                content: "", read: true, feed: feed1, flags: [], enclosures: [])

            feed1.addArticle(article1)
            feed1.addArticle(article2)

            feed2 = Feed(title: "d", url: nil, summary: "", query: "function(article) {return true;}", tags: ["b", "d"],
                waitPeriod: 0, remainingWait: 0, articles: [article1, article2], image: nil)

            feed3 = Feed(title: "e", url: NSURL(string: "https://example.com/feed3.feed"), summary: "", query: nil,
                tags: ["dad"], waitPeriod: 0, remainingWait: 1, articles: [], image: nil)

            feeds = [feed1, feed2, feed3]

            reachable = FakeReachable(hasNetworkConnectivity: true)

            mainQueue = FakeOperationQueue()
            backgroundQueue = FakeOperationQueue()

            dataService = InMemoryDataService()

            dataService.feeds = feeds
            dataService.articles = [article1, article2]

            updateService = FakeUpdateService()

            subject = DataRepository(mainQueue: mainQueue,
                backgroundQueue: backgroundQueue,
                reachable: reachable,
                dataService: dataService,
                updateService: updateService
            )

            dataSubscriber = FakeDataSubscriber()
            subject.addSubscriber(dataSubscriber)
        }

        afterEach {
            feeds = []
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
                    expect(calledHandler).to(beTruthy())
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
                    expect(calledHandler).to(beTruthy())
                    expect(calledFeeds).to(equal(feeds))
                    for (idx, feed) in feeds.enumerate() {
                        let calledFeed = calledFeeds[idx]
                        expect(calledFeed.articlesArray == feed.articlesArray).to(beTruthy())
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

                        expect(calledHandler).to(beTruthy())
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
                    backgroundQueue.runNextOperation()
                }

                it("should return all articles that match the given search query") {
                    expect(mainQueue.operationCount).to(equal(1))

                    expect(calledHandler).to(beFalsy())

                    mainQueue.runNextOperation()

                    expect(mainQueue.operationCount).to(equal(0))
                    expect(calledHandler).to(beTruthy())
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

                    expect(calledHandler).to(beFalsy())

                    mainQueue.runNextOperation()

                    expect(mainQueue.operationCount).to(equal(0))
                    expect(calledHandler).to(beTruthy())
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
                    backgroundQueue.runSynchronously = true
                    subject.markFeedAsRead(feed1)
                }

                it("should mark every article in the feed as read") {
                    for article in feed1.articlesArray {
                        expect(article.read).to(beTruthy())
                    }
                }

                it("should inform any subscribers") {
                    expect(dataSubscriber.markedArticles).toNot(beNil())
                    expect(dataSubscriber.read).to(beTruthy())
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

                    backgroundQueue.runSynchronously = true

                    subject.markArticle(article, asRead: true)
                }

                it("should mark the article object as read") {
                    expect(article.read).to(beTruthy())
                }

                it("should inform any subscribers") {
                    expect(dataSubscriber.markedArticles).to(equal([article]))
                    expect(dataSubscriber.read).to(beTruthy())
                }

                describe("and marking it as unread again") {
                    beforeEach {
                        dataSubscriber.markedArticles = nil
                        dataSubscriber.read = nil
                        subject.markArticle(article, asRead: false)
                    }

                    it("should inform any subscribers") {
                        expect(dataSubscriber.markedArticles).to(equal([article]))
                        expect(dataSubscriber.read).to(beFalsy())
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
                        expect(dataSubscriber.didStartUpdatingFeeds).to(beFalsy())
                    }

                    it("should not make an update request") {
                        expect(updateService.updatedFeed).to(beNil())
                    }

                    it("should call the completion handler without an error and with the original feed") {
                        expect(didCallCallback).to(beTruthy())
                        expect(callbackError).to(beNil())
                        expect(updatedFeed).to(equal(feed))
                    }
                }

                context("when the network is reachable") {
                    beforeEach {
                        backgroundQueue.runSynchronously = true

                        subject.updateFeed(feed) {changedFeed, error in
                            didCallCallback = true
                            callbackError = error
                        }
                    }

                    it("should inform any subscribers") {
                        expect(dataSubscriber.didStartUpdatingFeeds).to(beTruthy())
                    }

                    it("should make a network request for the feed if it has a remaniing wait of 0") {
                        expect(updateService.updatedFeed) == feed
                    }

                    context("when the network request succeeds") {
                        beforeEach {
                            expect(updateService.updatedFeedCallback).toNot(beNil())
                            updateService.updatedFeedCallback?(feed)
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
                                expect(dataSubscriber.updatedFeeds).to(beTruthy())
                            }

                            it("should call the completion handler without an error") {
                                expect(didCallCallback).to(beTruthy())
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
                    backgroundQueue.runSynchronously = true
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
                        expect(dataSubscriber.didStartUpdatingFeeds).to(beFalsy())
                    }

                    it("should call the callback with no errors") {
                        expect(didCallCallback).to(beTruthy())
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
                        expect(dataSubscriber.didStartUpdatingFeeds).to(beFalsy())
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
                        expect(didCallCallback).to(beTruthy())
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
                        backgroundQueue.runSynchronously = true
                        subject.updateFeeds {feeds, errors in
                            didCallCallback = true
                            callbackErrors = errors
                        }
                    }

                    it("should inform any subscribers") {
                        expect(dataSubscriber.didStartUpdatingFeeds).to(beTruthy())
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
                            expect(dataSubscriber.didStartUpdatingFeeds).to(beFalsy())
                        }

                        it("should not make any update requests") {
                            expect(updateService.updatedFeed).to(beNil())
                        }

                        it("should not immediately call the callback") {
                            expect(didCallUpdateCallback).to(beFalsy())
                        }

                        context("when the original update request finishes") {
                            beforeEach {
                                mainQueue.runSynchronously = true
                                updateService.updatedFeedCallback?(feed1)
                            }

                            it("should call both completion handlers") {
                                expect(didCallCallback).to(beTruthy())
                                expect(callbackErrors).to(equal([]))
                                expect(didCallUpdateCallback).to(beTruthy())
                            }
                        }
                    }

                    context("when the update request succeeds") {
                        beforeEach {
                            mainQueue.runSynchronously = true
                            updateService.updatedFeedCallback?(feed1)
                        }

                        it("should inform subscribers that we downloaded a thing and are about to process it") {
                            expect(dataSubscriber.updateFeedsProgressFinished).to(equal(1))
                            expect(dataSubscriber.updateFeedsProgressTotal).to(equal(1))
                        }

                        it("should call the completion handler without an error") {
                            expect(didCallCallback).to(beTruthy())
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

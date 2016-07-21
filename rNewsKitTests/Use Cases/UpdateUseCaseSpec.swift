import Quick
import Nimble
@testable import rNewsKit
import Result
import CBGPromise

class UpdateUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultUpdateUseCase!
        var updateService: FakeUpdateService!
        var mainQueue: FakeOperationQueue!

        var feeds: [Feed] = []
        var feed1: Feed!
        var feed3: Feed!

        var article1: Article!
        var article2: Article!

        var dataSubscriber: FakeDataSubscriber!

        beforeEach {
            feed1 = Feed(title: "a", url: NSURL(string: "https://example.com/feed1.feed"), summary: "",
                query: nil, tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            article1 = Article(title: "b", link: NSURL(string: "https://example.com/article1.html"),
                summary: "<p>Hello world!</p>", authors: [], published: NSDate(), updatedAt: nil, identifier: "article1",
                content: "", read: false, estimatedReadingTime: 0, feed: feed1, flags: [], enclosures: [])

            article2 = Article(title: "c", link: NSURL(string: "https://example.com/article2.html"),
                summary: "<p>Hello world!</p>", authors: [], published: NSDate(), updatedAt: nil, identifier: "article2",
                content: "", read: true, estimatedReadingTime: 0, feed: feed1, flags: [], enclosures: [])

            feed1.addArticle(article1)
            feed1.addArticle(article2)

            feed3 = Feed(title: "e", url: NSURL(string: "https://example.com/feed3.feed"), summary: "", query: nil,
                tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            
            feeds = [feed1, feed3]

            dataSubscriber = FakeDataSubscriber()

            updateService = FakeUpdateService()
            mainQueue = FakeOperationQueue()
            subject = DefaultUpdateUseCase(updateService: updateService, mainQueue: mainQueue)
        }

        describe("without a Pasiphae account") {
            var receivedFuture: Future<Result<Void, RNewsError>>!
            beforeEach {
                receivedFuture = subject.updateFeeds(feeds, subscribers: [dataSubscriber])
            }

            it("informs any subscribers") {
                expect(dataSubscriber.didStartUpdatingFeeds) == true
            }

            it("smakes a network request for every feed in the data store w/ a url") {
                expect(updateService.updatedFeeds) == [feed1, feed3]
            }

            context("when the update request succeeds") {
                beforeEach {
                    mainQueue.runSynchronously = true
                    let updatingFeeds = [feed1, feed3]
                    updateService.updateFeedCallbacks.enumerate().forEach {
                        $1(updatingFeeds[$0], nil)
                    }
                }

                it("should inform subscribers that we downloaded a thing and are about to process it") {
                    expect(dataSubscriber.updateFeedsProgressFinished).to(equal(2))
                    expect(dataSubscriber.updateFeedsProgressTotal).to(equal(2))
                }

                it("should call the completion handler without an error") {
                    expect(receivedFuture.value?.value).toNot(beNil())
                }
            }
        }
    }
}

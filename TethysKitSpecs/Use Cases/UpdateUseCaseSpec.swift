import Quick
import Nimble
@testable import TethysKit
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

        var userDefaults: FakeUserDefaults!

        beforeEach {
            feed1 = Feed(title: "a", url: URL(string: "https://example.com/feed1.feed")!, summary: "",
                tags: ["a", "b", "c", "d"], articles: [], image: nil)

            article1 = Article(title: "b", link: URL(string: "https://example.com/article1.html")!,
                summary: "<p>Hello world!</p>", authors: [], published: Date(), updatedAt: nil, identifier: "article1",
                content: "", read: false, synced: false, feed: feed1, flags: [])

            article2 = Article(title: "c", link: URL(string: "https://example.com/article2.html")!,
                summary: "<p>Hello world!</p>", authors: [], published: Date(), updatedAt: nil, identifier: "article2",
                content: "", read: true, synced: false, feed: feed1, flags: [])

            feed1.addArticle(article1)
            feed1.addArticle(article2)

            feed3 = Feed(title: "e", url: URL(string: "https://example.com/feed3.feed")!, summary: "",
                tags: ["dad"], articles: [], image: nil)

            feeds = [feed1, feed3]

            dataSubscriber = FakeDataSubscriber()

            updateService = FakeUpdateService()
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            userDefaults = FakeUserDefaults()
            subject = DefaultUpdateUseCase(
                updateService: updateService,
                mainQueue: mainQueue,
                userDefaults: userDefaults
            )
        }
        
        describe("-updateFeeds") {
            var receivedFuture: Future<Result<Void, TethysError>>!
            beforeEach {
                receivedFuture = subject.updateFeeds(feeds, subscribers: [dataSubscriber])
            }

            it("informs any subscribers") {
                expect(dataSubscriber.didStartUpdatingFeeds) == true
            }

            it("makes a network request for every feed in the data store w/ a url") {
                expect(updateService.updatedFeeds) == [feed1, feed3]
            }

            context("when the update request succeeds") {
                beforeEach {
                    mainQueue.runSynchronously = true
                    let updatingFeeds = [feed1, feed3]
                    updateService.updateFeedPromises.enumerated().forEach {
                        $1.resolve(.success(updatingFeeds[$0]!))
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

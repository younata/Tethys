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
        var accountRepository: FakeAccountRepository!

        var userDefaults: FakeUserDefaults!

        beforeEach {
            feed1 = Feed(title: "a", url: URL(string: "https://example.com/feed1.feed")!, summary: "",
                tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            article1 = Article(title: "b", link: URL(string: "https://example.com/article1.html"),
                summary: "<p>Hello world!</p>", authors: [], published: Date(), updatedAt: nil, identifier: "article1",
                content: "", read: false, estimatedReadingTime: 0, feed: feed1, flags: [])

            article2 = Article(title: "c", link: URL(string: "https://example.com/article2.html"),
                summary: "<p>Hello world!</p>", authors: [], published: Date(), updatedAt: nil, identifier: "article2",
                content: "", read: true, estimatedReadingTime: 0, feed: feed1, flags: [])

            feed1.addArticle(article1)
            feed1.addArticle(article2)

            feed3 = Feed(title: "e", url: URL(string: "https://example.com/feed3.feed")!, summary: "",
                tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            feeds = [feed1, feed3]

            dataSubscriber = FakeDataSubscriber()

            updateService = FakeUpdateService()
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            accountRepository = FakeAccountRepository()
            userDefaults = FakeUserDefaults()
            subject = DefaultUpdateUseCase(updateService: updateService, mainQueue: mainQueue, accountRepository: accountRepository, userDefaults: userDefaults)
        }

        describe("-updateFeeds") {
            describe("with a Pasiphae account") {
                var receivedFuture: Future<Result<Void, RNewsError>>!
                var updateFeedsPromise: Promise<Result<[rNewsKit.Feed], RNewsError>>!

                beforeEach {
                    accountRepository.loggedInReturns("foo@example.com")
                    updateFeedsPromise = Promise<Result<[rNewsKit.Feed], RNewsError>>()
                    updateService.updateFeedsReturns(updateFeedsPromise.future)

                    receivedFuture = subject.updateFeeds(feeds, subscribers: [dataSubscriber])
                }

                it("informs any subscribers") {
                    expect(dataSubscriber.didStartUpdatingFeeds) == true
                }

                it("makes an update request to pasiphae") {
                    expect(updateService.updateFeedsCallCount) == 1
                }

                it("informs the data subscribers whenever there's stuff to update") {
                    guard updateService.updateFeedsCallCount == 1 else { fail(); return }
                    let args = updateService.updateFeedsArgsForCall(0)
                    args(1, 2)

                    expect(dataSubscriber.didUpdateFeedsArgs.count) == 1
                    expect(dataSubscriber.didUpdateFeedsArgs[0].0) == 1
                    expect(dataSubscriber.didUpdateFeedsArgs[0].1) == 2
                }

                describe("when the update request succeeds") {
                    beforeEach {
                        updateFeedsPromise.resolve(.success([]))
                    }

                    it("resolves the promise successfully") {
                        expect(receivedFuture.value?.value).toNot(beNil())
                    }
                }

                describe("when the update request fails") {
                    beforeEach {
                        updateFeedsPromise.resolve(.failure(.unknown))
                    }

                    it("resolves the promise with the error") {
                        expect(receivedFuture.value?.error) == .unknown
                    }
                }
            }

            describe("without a Pasiphae account") {
                var receivedFuture: Future<Result<Void, RNewsError>>!
                beforeEach {
                    accountRepository.loggedInReturns(nil)

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
                        updateService.updateFeedCallbacks.enumerated().forEach {
                            $1(updatingFeeds[$0]!, nil)
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
}

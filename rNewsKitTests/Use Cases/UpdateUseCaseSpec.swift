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
            feed1 = Feed(title: "a", url: NSURL(string: "https://example.com/feed1.feed"), summary: "",
                query: nil, tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            article1 = Article(title: "b", link: NSURL(string: "https://example.com/article1.html"),
                summary: "<p>Hello world!</p>", authors: [], published: NSDate(), updatedAt: nil, identifier: "article1",
                content: "", read: false, estimatedReadingTime: 0, feed: feed1, flags: [])

            article2 = Article(title: "c", link: NSURL(string: "https://example.com/article2.html"),
                summary: "<p>Hello world!</p>", authors: [], published: NSDate(), updatedAt: nil, identifier: "article2",
                content: "", read: true, estimatedReadingTime: 0, feed: feed1, flags: [])

            feed1.addArticle(article1)
            feed1.addArticle(article2)

            feed3 = Feed(title: "e", url: NSURL(string: "https://example.com/feed3.feed"), summary: "", query: nil,
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
                var updateFeedsPromise: Promise<Result<(NSDate, [rNewsKit.Feed]), RNewsError>>!

                let initialDate = NSDate()

                beforeEach {
                    accountRepository.loggedInReturns("foo@example.com")
                    updateFeedsPromise = Promise<Result<(NSDate, [rNewsKit.Feed]), RNewsError>>()
                    updateService.updateFeedsReturns(updateFeedsPromise.future)

                    userDefaults.setObject(initialDate, forKey: "pasiphae_last_update_date")

                    receivedFuture = subject.updateFeeds(feeds, subscribers: [dataSubscriber])
                }

                it("informs any subscribers") {
                    expect(dataSubscriber.didStartUpdatingFeeds) == true
                }

                it("makes an update request to pasiphae") {
                    expect(updateService.updateFeedsCallCount) == 1
                    guard updateService.updateFeedsCallCount == 1 else { return }
                    let args = updateService.updateFeedsArgsForCall(0)
                    expect(args.0) == initialDate
                }

                it("informs the data subscribers whenever there's stuff to update") {
                    guard updateService.updateFeedsCallCount == 1 else { fail(); return }
                    let args = updateService.updateFeedsArgsForCall(0)
                    args.1(1, 2)

                    expect(dataSubscriber.didUpdateFeedsArgs.count) == 1
                    expect(dataSubscriber.didUpdateFeedsArgs[0].0) == 1
                    expect(dataSubscriber.didUpdateFeedsArgs[0].1) == 2
                }

                describe("when the update request succeeds") {
                    let updatedDate = NSDate()
                    beforeEach {
                        updateFeedsPromise.resolve(.Success(updatedDate, []))
                    }

                    it("stores the new updated date for future calls") {
                        expect(userDefaults.objectForKey("pasiphae_last_update_date") as? NSDate) == updatedDate
                    }

                    it("resolves the promise successfully") {
                        expect(receivedFuture.value?.value).toNot(beNil())
                    }
                }

                describe("when the update request fails") {
                    beforeEach {
                        updateFeedsPromise.resolve(.Failure(.Unknown))
                    }

                    it("resolves the promise with the error") {
                        expect(receivedFuture.value?.error) == .Unknown
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
}

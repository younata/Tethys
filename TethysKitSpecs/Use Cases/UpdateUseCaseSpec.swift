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

        var userDefaults: FakeUserDefaults!

        beforeEach {
            feed1 = Feed(title: "a", url: URL(string: "https://example.com/feed1.feed")!, summary: "",
                         tags: ["a", "b", "c", "d"], unreadCount: 0, image: nil)

            feed3 = Feed(title: "e", url: URL(string: "https://example.com/feed3.feed")!, summary: "",
                         tags: ["dad"], unreadCount: 0, image: nil)

            feeds = [feed1, feed3]

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
        
        describe("updateFeeds()") {
            var receivedFuture: Future<Result<Void, TethysError>>!
            beforeEach {
                receivedFuture = subject.updateFeeds(feeds)
            }

            it("makes a network request for every feed in the data store w/ a url") {
                expect(updateService.updateFeedCalls) == [feed1, feed3]
            }

            context("when the update request succeeds") {
                beforeEach {
                    mainQueue.runSynchronously = true
                    let updatingFeeds = [feed1, feed3]
                    updateService.updateFeedPromises.enumerated().forEach {
                        $1.resolve(.success(updatingFeeds[$0]!))
                    }
                }

                it("should call the completion handler without an error") {
                    expect(receivedFuture.value?.value).toNot(beNil())
                }
            }
        }
    }
}

@testable import rNewsKit
import CBGPromise
import Result

class FakeUpdateService: UpdateServiceType {
    var updatedFeeds: [Feed] = []
    var updateFeedCallbacks: [((Feed, NSError?) -> Void)] = []

    func updateFeed(feed: Feed, callback: (Feed, NSError?) -> Void) {
        self.updatedFeeds.append(feed)
        self.updateFeedCallbacks.append(callback)
    }

    private(set) var updateFeedsCallCount : Int = 0
    var updateFeedsStub : (() -> (Future<Result<([rNewsKit.Feed]), RNewsError>>))?
    private var updateFeedsArgs : Array<([rNewsKit.Feed], ((Int, Int) -> Void))> = []
    func updateFeedsReturns(stubbedValues: (Future<Result<([rNewsKit.Feed]), RNewsError>>)) {
        self.updateFeedsStub = {() -> (Future<Result<([rNewsKit.Feed]), RNewsError>>) in
            return stubbedValues
        }
    }
    func updateFeedsArgsForCall(callIndex: Int) -> ([rNewsKit.Feed], ((Int, Int) -> Void)) {
        return self.updateFeedsArgs[callIndex]
    }
    func updateFeeds(feeds: [rNewsKit.Feed], progressCallback: ((Int, Int) -> Void)) -> (Future<Result<[rNewsKit.Feed], RNewsError>>) {
        self.updateFeedsCallCount += 1
        self.updateFeedsArgs.append((feeds, progressCallback))
        return self.updateFeedsStub!()
    }
}
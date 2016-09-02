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
    private var updateFeedsArgs : Array<(((Int, Int) -> Void))> = []
    func updateFeedsReturns(stubbedValues: (Future<Result<([rNewsKit.Feed]), RNewsError>>)) {
        self.updateFeedsStub = {() -> (Future<Result<([rNewsKit.Feed]), RNewsError>>) in
            return stubbedValues
        }
    }
    func updateFeedsArgsForCall(callIndex: Int) -> (((Int, Int) -> Void)) {
        return self.updateFeedsArgs[callIndex]
    }
    func updateFeeds(progress: ((Int, Int) -> Void)) -> (Future<Result<[rNewsKit.Feed], RNewsError>>) {
        self.updateFeedsCallCount += 1
        self.updateFeedsArgs.append((progress))
        return self.updateFeedsStub!()
    }
}
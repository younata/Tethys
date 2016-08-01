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
    var updateFeedsStub : (() -> (Future<Result<(NSDate, [rNewsKit.Feed]), RNewsError>>))?
    private var updateFeedsArgs : Array<(NSDate?, ((Int, Int) -> Void))> = []
    func updateFeedsReturns(stubbedValues: (Future<Result<(NSDate, [rNewsKit.Feed]), RNewsError>>)) {
        self.updateFeedsStub = {() -> (Future<Result<(NSDate, [rNewsKit.Feed]), RNewsError>>) in
            return stubbedValues
        }
    }
    func updateFeedsArgsForCall(callIndex: Int) -> (NSDate?, ((Int, Int) -> Void)) {
        return self.updateFeedsArgs[callIndex]
    }
    func updateFeeds(date: NSDate?, progressCallback: ((Int, Int) -> Void)) -> (Future<Result<(NSDate, [rNewsKit.Feed]), RNewsError>>) {
        self.updateFeedsCallCount += 1
        self.updateFeedsArgs.append((date, progressCallback))
        return self.updateFeedsStub!()
    }
}
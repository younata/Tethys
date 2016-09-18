@testable import rNewsKit
import CBGPromise
import Result

class FakeUpdateService: UpdateServiceType {
    var updatedFeeds: [Feed] = []
    var updateFeedPromises: [Promise<Result<Feed, RNewsError>>] = []

    func updateFeed(_ feed: Feed) -> Future<Result<Feed, RNewsError>> {
        self.updatedFeeds.append(feed)
        let promise = Promise<Result<Feed, RNewsError>>()
        self.updateFeedPromises.append(promise)
        return promise.future
    }

    private(set) var updateFeedsCallCount : Int = 0
    var updateFeedsStub : (() -> (Future<Result<([rNewsKit.Feed]), RNewsError>>))?
    private var updateFeedsArgs : Array<(((Int, Int) -> Void))> = []
    func updateFeedsReturns(_ stubbedValues: (Future<Result<([rNewsKit.Feed]), RNewsError>>)) {
        self.updateFeedsStub = {() -> (Future<Result<([rNewsKit.Feed]), RNewsError>>) in
            return stubbedValues
        }
    }
    func updateFeedsArgsForCall(_ callIndex: Int) -> (((Int, Int) -> Void)) {
        return self.updateFeedsArgs[callIndex]
    }
    func updateFeeds(_ progress: @escaping ((Int, Int) -> Void)) -> (Future<Result<[rNewsKit.Feed], RNewsError>>) {
        self.updateFeedsCallCount += 1
        self.updateFeedsArgs.append((progress))
        return self.updateFeedsStub!()
    }
}

@testable import TethysKit
import CBGPromise
import Result

class FakeUpdateService: UpdateServiceType {
    var updatedFeeds: [Feed] = []
    var updateFeedPromises: [Promise<Result<Feed, TethysError>>] = []

    func updateFeed(_ feed: Feed) -> Future<Result<Feed, TethysError>> {
        self.updatedFeeds.append(feed)
        let promise = Promise<Result<Feed, TethysError>>()
        self.updateFeedPromises.append(promise)
        return promise.future
    }

    private(set) var updateFeedsCallCount : Int = 0
    var updateFeedsStub : (() -> (Future<Result<([TethysKit.Feed]), TethysError>>))?
    private var updateFeedsArgs : Array<(((Int, Int) -> Void))> = []
    func updateFeedsReturns(_ stubbedValues: (Future<Result<([TethysKit.Feed]), TethysError>>)) {
        self.updateFeedsStub = {() -> (Future<Result<([TethysKit.Feed]), TethysError>>) in
            return stubbedValues
        }
    }
    func updateFeedsArgsForCall(_ callIndex: Int) -> (((Int, Int) -> Void)) {
        return self.updateFeedsArgs[callIndex]
    }
    func updateFeeds(_ progress: @escaping ((Int, Int) -> Void)) -> (Future<Result<[TethysKit.Feed], TethysError>>) {
        self.updateFeedsCallCount += 1
        self.updateFeedsArgs.append((progress))
        return self.updateFeedsStub!()
    }
}

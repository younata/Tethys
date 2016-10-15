import rNews
import rNewsKit
import CBGPromise

class FakeFeedsSource: FeedsSource {
    var feeds: [Feed] = []

    var editFeedCallCount: Int = 0
    private var editFeedArgs: [Feed] = []
    func editFeedArgsForCall(callIndex: Int) -> Feed {
        return self.editFeedArgs[callIndex]
    }
    func editFeed(feed: Feed) {
        self.editFeedCallCount += 1
        self.editFeedArgs.append(feed)
    }

    var shareFeedCallCount: Int = 0
    private var shareFeedArgs: [Feed] = []
    func shareFeedArgsForCall(callIndex: Int) -> Feed {
        return self.shareFeedArgs[callIndex]
    }
    func shareFeed(feed: Feed) {
        self.shareFeedCallCount += 1
        self.shareFeedArgs.append(feed)
    }

    var markReadCallCount: Int = 0
    private var markReadArgs: [Feed] = []
    var markReadPromises: [Promise<Void>] = []
    func markReadArgsForCall(callIndex: Int) -> Feed {
        return self.markReadArgs[callIndex]
    }
    func markRead(feed: Feed) -> Future<Void> {
        self.markReadCallCount += 1
        self.markReadArgs.append(feed)
        let promise = Promise<Void>()
        self.markReadPromises.append(promise)
        return promise.future
    }

    var deleteFeedCallCount: Int = 0
    private var deleteFeedArgs: [Feed] = []
    var deleteFeedPromises: [Promise<Bool>] = []
    func deleteFeedArgsForCall(callIndex: Int) -> Feed {
        return self.deleteFeedArgs[callIndex]
    }
    func deleteFeed(feed: Feed) -> Future<Bool> {
        self.deleteFeedCallCount += 1
        self.deleteFeedArgs.append(feed)
        let promise = Promise<Bool>()
        self.deleteFeedPromises.append(promise)
        return promise.future
    }
}

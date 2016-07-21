import CBGPromise
import Result

protocol UpdateUseCase {
    func updateFeeds(feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>>
}

final class DefaultUpdateUseCase: UpdateUseCase {
    private let updateService: UpdateServiceType
    private let mainQueue: NSOperationQueue

    init(updateService: UpdateServiceType, mainQueue: NSOperationQueue) {
        self.updateService = updateService
        self.mainQueue = mainQueue
    }

    func updateFeeds(feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>> {
        return self.updateFeedsFromRSS(feeds, subscribers: subscribers)
    }

    func updateFeedsFromBackend(date: NSDate?, subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        return promise.future
    }

    func updateFeedsFromRSS(feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>> {
        var feedsLeft = feeds.count
        let promise = Promise<Result<Void, RNewsError>>()
        guard feedsLeft != 0 else {
            promise.resolve(.Failure(.Unknown))
            return promise.future
        }

        for subscriber in subscribers {
            subscriber.willUpdateFeeds()
        }

        var updatedFeeds: [Feed] = []

        let totalProgress = feedsLeft
        var currentProgress = 0

        for feed in feeds {
            self.updateService.updateFeed(feed) { feed, _ in
                updatedFeeds.append(feed)

                currentProgress += 1
                self.mainQueue.addOperationWithBlock {
                    for subscriber in subscribers {
                        subscriber.didUpdateFeedsProgress(currentProgress, total: totalProgress)
                    }
                }

                feedsLeft -= 1
                if feedsLeft == 0 {
                    promise.resolve(.Success())
                }
            }
        }

        return promise.future
    }
}

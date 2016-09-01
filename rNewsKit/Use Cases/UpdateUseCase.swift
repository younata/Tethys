import CBGPromise
import Result

protocol UpdateUseCase {
    func updateFeeds(feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>>
}

final class DefaultUpdateUseCase: UpdateUseCase {
    private let updateService: UpdateServiceType
    private let mainQueue: NSOperationQueue
    private let accountRepository: InternalAccountRepository
    private let userDefaults: NSUserDefaults

    init(updateService: UpdateServiceType,
         mainQueue: NSOperationQueue,
         accountRepository: InternalAccountRepository,
         userDefaults: NSUserDefaults) {
        self.updateService = updateService
        self.mainQueue = mainQueue
        self.accountRepository = accountRepository
        self.userDefaults = userDefaults
    }

    func updateFeeds(feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>> {
        if self.accountRepository.loggedIn() != nil {
            return self.updateFeedsFromBackend(feeds, subscribers: subscribers)
        } else {
            return self.updateFeedsFromRSS(feeds, subscribers: subscribers)
        }
    }

    func updateFeedsFromBackend(feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>> {
        self.mainQueue.addOperationWithBlock {
            for subscriber in subscribers {
                subscriber.willUpdateFeeds()
            }
        }
        let future = self.updateService.updateFeeds(feeds) { progress, total in
            self.mainQueue.addOperationWithBlock {
                for subscriber in subscribers {
                    subscriber.didUpdateFeedsProgress(progress, total: total)
                }
            }
        }
        return future.map { (res: Result<[Feed], RNewsError>) in
            return res.map { _ in
                return
            }
        }
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

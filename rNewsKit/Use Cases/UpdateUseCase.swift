import CBGPromise
import Result

protocol UpdateUseCase {
    func updateFeeds(_ feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>>
}

final class DefaultUpdateUseCase: UpdateUseCase {
    private let updateService: UpdateServiceType
    private let mainQueue: OperationQueue
    private let accountRepository: InternalAccountRepository
    private let userDefaults: UserDefaults

    init(updateService: UpdateServiceType,
         mainQueue: OperationQueue,
         accountRepository: InternalAccountRepository,
         userDefaults: UserDefaults) {
        self.updateService = updateService
        self.mainQueue = mainQueue
        self.accountRepository = accountRepository
        self.userDefaults = userDefaults
    }

    func updateFeeds(_ feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>> {
        if self.accountRepository.loggedIn() != nil {
            return self.updateFeedsFromBackend(feeds, subscribers: subscribers)
        } else {
            return self.updateFeedsFromRSS(feeds, subscribers: subscribers)
        }
    }

    func updateFeedsFromBackend(_ feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>> {
        self.mainQueue.addOperation {
            for subscriber in subscribers {
                subscriber.willUpdateFeeds()
            }
        }
        let future = self.updateService.updateFeeds { progress, total in
            self.mainQueue.addOperation {
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

    func updateFeedsFromRSS(_ feeds: [Feed], subscribers: [DataSubscriber]) -> Future<Result<Void, RNewsError>> {
        var feedsLeft = feeds.count
        let promise = Promise<Result<Void, RNewsError>>()
        guard feedsLeft != 0 else {
            promise.resolve(.failure(.unknown))
            return promise.future
        }

        for subscriber in subscribers {
            subscriber.willUpdateFeeds()
        }

        var updatedFeeds: [Feed] = []

        let totalProgress = feedsLeft
        var currentProgress = 0

        for feed in feeds {
            _ = self.updateService.updateFeed(feed).then {
                if case let .success(updatedFeed) = $0 {
                    updatedFeeds.append(updatedFeed)
                } else {
                    updatedFeeds.append(feed)
                }

                currentProgress += 1
                self.mainQueue.addOperation {
                    for subscriber in subscribers {
                        subscriber.didUpdateFeedsProgress(currentProgress, total: totalProgress)
                    }
                }

                feedsLeft -= 1
                if feedsLeft == 0 {
                    promise.resolve(.success())
                }
            }
        }

        return promise.future
    }
}

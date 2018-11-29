import CBGPromise
import Result

protocol UpdateUseCase {
    func updateFeeds(_ feeds: [Feed]) -> Future<Result<Void, TethysError>>
}

final class DefaultUpdateUseCase: UpdateUseCase {
    private let updateService: UpdateService
    private let mainQueue: OperationQueue
    private let userDefaults: UserDefaults

    init(updateService: UpdateService,
         mainQueue: OperationQueue,
         userDefaults: UserDefaults) {
        self.updateService = updateService
        self.mainQueue = mainQueue
        self.userDefaults = userDefaults
    }

    func updateFeeds(_ feeds: [Feed]) -> Future<Result<Void, TethysError>> {
        var feedsLeft = feeds.count
        let promise = Promise<Result<Void, TethysError>>()
        guard feedsLeft != 0 else {
            promise.resolve(.failure(.unknown))
            return promise.future
        }

        var updatedFeeds: [Feed] = []

        var currentProgress = 0

        for feed in feeds {
            _ = self.updateService.updateFeed(feed).then {
                if case let .success(updatedFeed) = $0 {
                    updatedFeeds.append(updatedFeed)
                } else {
                    updatedFeeds.append(feed)
                }

                currentProgress += 1

                feedsLeft -= 1
                if feedsLeft == 0 {
                    promise.resolve(.success())
                }
            }
        }

        return promise.future
    }
}

import Result
import CBGPromise

public class FeedCoordinator {
    private let localFeedService: LocalFeedService
    private let networkFeedServiceProvider: () -> FeedService

    init(localFeedService: LocalFeedService, networkFeedServiceProvider: @escaping () -> FeedService) {
        self.localFeedService = localFeedService
        self.networkFeedServiceProvider = networkFeedServiceProvider
    }

    // MARK: Getting the current list of feeds
    private var lastFeedsPublisher: Publisher<Result<AnyCollection<Feed>, TethysError>>?
    public func feeds() -> Subscription<Result<AnyCollection<Feed>, TethysError>> {
        if let subscription = self.lastFeedsPublisher?.subscription, subscription.isFinished == false {
            return subscription
        }
        let publisher = Publisher<Result<AnyCollection<Feed>, TethysError>>()
        self.lastFeedsPublisher = publisher

        self.localFeedService.feeds().then {
            publisher.update(with: $0)
        }.map { _ in
            self.networkFeedServiceProvider().feeds()
        }.map { updatedFeeds -> Future<Result<AnyCollection<Feed>, TethysError>> in
            if self.shouldPublishUpdates(updatedFeeds, existing: publisher.subscription.value) {
                publisher.update(with: updatedFeeds)
            }
            switch updatedFeeds {
            case .success(let feeds):
                return self.localFeedService.updateFeeds(with: feeds)
            case .failure(let error):
                return Promise<Result<AnyCollection<Feed>, TethysError>>.resolved(.failure(error))
            }
        }.then { savedFeeds in
            if self.shouldPublishUpdates(savedFeeds, existing: publisher.subscription.value) {
                publisher.update(with: savedFeeds)
            }
            publisher.finish()
            self.lastFeedsPublisher = nil
        }

        return publisher.subscription
    }

    /** Returns whether or not to publish the updated feeds.

        If the existingFeeds is nil: of course we should publish the new things.
        If the updatedFeeds succeeded, then we should publish those as well.
        However, if the update failed for some reason, but the local feeds didn't, then the user shouldn't see an error.
        BUT if local failed for some reason, then we should publish both errors.
        We don't want the user to see feeds, then suddenly have no data, that's a bad user experience.
     */
    private func shouldPublishUpdates<T>(
        _ updated: Result<AnyCollection<T>, TethysError>,
        existing existingResult: Result<AnyCollection<T>, TethysError>?
    ) -> Bool {
        guard let existing = existingResult else { return true }
        if updated.succeeded { return true }
        return existing.errored
    }

    // MARK: Retrieving articles of a feed
    private var articlesPublishers: [Feed: Publisher<Result<AnyCollection<Article>, TethysError>>] = [:]
    public func articles(of feed: Feed) -> Subscription<Result<AnyCollection<Article>, TethysError>> {
        if let publisher = self.articlesPublishers[feed], publisher.isFinished == false {
            return publisher.subscription
        }
        let publisher = Publisher<Result<AnyCollection<Article>, TethysError>>()
        articlesPublishers[feed] = publisher

        self.localFeedService.articles(of: feed).then {
            publisher.update(with: $0)
        }.map { _ in
            self.networkFeedServiceProvider().articles(of: feed)
        }.map { networkArticles -> Future<Result<AnyCollection<Article>, TethysError>> in
            if self.shouldPublishUpdates(networkArticles, existing: publisher.subscription.value) {
                publisher.update(with: networkArticles)
            }

            switch networkArticles {
            case .success(let articles):
                return self.localFeedService.updateArticles(with: articles, feed: feed)
            case .failure(let error):
                return Promise<Result<AnyCollection<Article>, TethysError>>.resolved(.failure(error))
            }
        }.then { savedArticles in
            if self.shouldPublishUpdates(savedArticles, existing: publisher.subscription.value) {
                publisher.update(with: savedArticles)
            }
            publisher.finish()
            self.articlesPublishers.removeValue(forKey: feed)
        }

        return publisher.subscription
    }

    // MARK: Subscribing to a feed
    public func subscribe(to url: URL) -> Future<Result<Feed, TethysError>> {
        let localFuture = self.localFeedService.subscribe(to: url)
        let networkFuture = self.networkFeedServiceProvider().subscribe(to: url)
        return Promise<Result<Feed, TethysError>>.when([localFuture, networkFuture]).map { results in
            guard results.count == 2, let localResult = results.first, let networkResult = results.last else {
                return Promise<Result<Feed, TethysError>>.resolved(Result<Feed, TethysError>.failure(.unknown))
            }

            switch networkResult {
            case .success(let networkFeed):
                guard localResult.value != networkFeed else {
                    return Promise<Result<Feed, TethysError>>.resolved(Result<Feed, TethysError>.success(networkFeed))
                }
                return self.localFeedService.updateFeed(from: networkFeed)
                    .map { updateResult -> Result<Feed, TethysError> in
                        switch updateResult {
                        case .success(let updatedFeed):
                            return .success(updatedFeed)
                        case .failure:
                            return .success(networkFeed)
                        }
                }
            case .failure(let networkError): // which is not a NetworkError
                switch localResult {
                case .success(let localFeed):
                    return Promise<Result<Feed, TethysError>>.resolved(Result<Feed, TethysError>.success(localFeed))
                case .failure(let localError):
                    return Promise<Result<Feed, TethysError>>.resolved(
                        Result<Feed, TethysError>.failure(.multiple([localError, networkError]))
                    )
                }
            }
        }
    }

    // MARK: Unsubscribing from a feed
    /** Unsubscribe from a feed
     This is one of the only cases where we apply an AND to success and not an OR.
     Because of the way syncing will work, if we unsubscribe from one but not the other,
     on the next sync, that unsubscribe will be rewritten.

     TODO: Figure out how unsubscribing on the web side of the network service will reflect here.
     */
    public func unsubscribe(from feed: Feed) -> Future<Result<Void, TethysError>> {
        let localFuture = self.localFeedService.remove(feed: feed)
        let networkFuture = self.networkFeedServiceProvider().remove(feed: feed)
        return Promise<Result<Void, TethysError>>.when([localFuture, networkFuture])
            .map { results -> Result<Void, TethysError> in
                guard results.count == 2, let localResult = results.first, let networkResult = results.last else {
                    return .failure(.unknown)
                }
                switch (localResult, networkResult) {
                case (.success, .success):
                    return .success(Void())
                case (.success, .failure(let error)):
                    return .failure(error)
                case (.failure(let error), .success):
                    return .failure(error)
                case (.failure(let localError), .failure(let networkError)):
                    return .failure(.multiple([localError, networkError]))
                }
        }
    }

    // MARK: Marking all articles of a feed as read
    public func readAll(of feed: Feed) -> Future<Result<Void, TethysError>> {
        feed.unreadCount = 0
        let localFuture = self.localFeedService.readAll(of: feed)
        let networkFuture = self.networkFeedServiceProvider().readAll(of: feed)
        return Promise<Result<Void, TethysError>>.when([localFuture, networkFuture])
            .map { results -> Result<Void, TethysError> in
                guard results.count == 2, let localResult = results.first, let networkResult = results.last else {
                    return .failure(.unknown)
                }
                switch (localResult, networkResult) {
                case (.success, .success):
                    return .success(Void())
                case (.success, .failure):
                    return .success(Void())
                case (.failure, .success):
                    return .success(Void())
                case (.failure(let localError), .failure(let networkError)):
                    return .failure(.multiple([localError, networkError]))
                }
        }
    }
}

extension Result {
    var succeeded: Bool {
        return self.value != nil
    }
    var errored: Bool {
        return self.error != nil
    }
}

import Result
import CBGPromise

final class FeedRepository: FeedService {
    private var feedService: FeedService

    init(feedService: FeedService) {
        self.feedService = feedService
    }

    private var feedsFuture: Future<Result<AnyCollection<Feed>, TethysError>>?
    func feeds() -> Future<Result<AnyCollection<Feed>, TethysError>> {
        if let future = self.feedsFuture, future.value == nil { return future }
        let future = self.feedService.feeds()
        self.feedsFuture = future
        return future
    }

    private var articlesFutures: [Feed: Future<Result<AnyCollection<Article>, TethysError>>] = [:]
    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>> {
        if let future = self.articlesFutures[feed], future.value == nil {
            return future
        }
        let future = self.feedService.articles(of: feed)
        self.articlesFutures[feed] = future
        return future
    }

    private var subscribeFutures: [URL: Future<Result<Feed, TethysError>>] = [:]
    func subscribe(to url: URL) -> Future<Result<Feed, TethysError>> {
        if let future = self.subscribeFutures[url], future.value == nil {
            return future
        }
        let future = self.feedService.subscribe(to: url)
        self.subscribeFutures[url] = future
        return future
    }

    private var tagsFuture: Future<Result<AnyCollection<String>, TethysError>>?
    func tags() -> Future<Result<AnyCollection<String>, TethysError>> {
        if let future = self.tagsFuture, future.value == nil { return future }
        let future = self.feedService.tags()
        self.tagsFuture = future
        return future
    }

    private var setTagsFutures: [Feed: Future<Result<Feed, TethysError>>] = [:]
    func set(tags: [String], of feed: Feed) -> Future<Result<Feed, TethysError>> {
        if let future = self.setTagsFutures[feed], future.value == nil { return future }
        let future = self.feedService.set(tags: tags, of: feed)
        self.setTagsFutures[feed] = future
        return future
    }

    private var setURLFutures: [Feed: Future<Result<Feed, TethysError>>] = [:]
    func set(url: URL, on feed: Feed) -> Future<Result<Feed, TethysError>> {
        if let future = self.setURLFutures[feed], future.value == nil { return future }
        let future = self.feedService.set(url: url, on: feed)
        self.setURLFutures[feed] = future
        return future
    }

    private var readFutures: [Feed: Future<Result<Void, TethysError>>] = [:]
    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>> {
        if let future = self.readFutures[feed], future.value == nil { return future }
        let future = self.feedService.readAll(of: feed)
        self.readFutures[feed] = future
        return future
    }

    private var removeFutures: [Feed: Future<Result<Void, TethysError>>] = [:]
    func remove(feed: Feed) -> Future<Result<Void, TethysError>> {
        if let future = self.removeFutures[feed], future.value == nil { return future }
        let future = self.feedService.remove(feed: feed)
        self.removeFutures[feed] = future
        return future
    }
}

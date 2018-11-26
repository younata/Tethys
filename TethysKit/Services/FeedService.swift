import Result
import CBGPromise

public protocol FeedService {
    func feeds() -> Future<Result<AnyCollection<Feed>, TethysError>>
    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>>

    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>>
    func remove(feed: Feed) -> Future<Result<Void, TethysError>>
}

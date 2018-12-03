import Result
import CBGPromise

public protocol FeedService {
    func feeds() -> Future<Result<AnyCollection<Feed>, TethysError>>
    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>>

    func subscribe(to url: URL) -> Future<Result<Feed, TethysError>>

    func set(tags: [String], of feed: Feed) -> Future<Result<Feed, TethysError>>
    func set(url: URL, on feed: Feed) -> Future<Result<Feed, TethysError>>

    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>>
    func remove(feed: Feed) -> Future<Result<Void, TethysError>>
}

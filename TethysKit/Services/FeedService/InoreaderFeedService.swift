import Result
import CBGPromise
import FutureHTTP

struct InoreaderFeedService: FeedService {
    func feeds() -> Future<Result<AnyCollection<Feed>, TethysError>> {
        return Promise<Result<AnyCollection<Feed>, TethysError>>().future
    }

    func articles(of feed: Feed) -> Future<Result<AnyCollection<Article>, TethysError>> {
        return Promise<Result<AnyCollection<Article>, TethysError>>().future
    }

    func subscribe(to url: URL) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>().future
    }

    func tags() -> Future<Result<AnyCollection<String>, TethysError>> {
        return Promise<Result<AnyCollection<String>, TethysError>>().future
    }

    func set(tags: [String], of feed: Feed) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>().future
    }

    func set(url: URL, on feed: Feed) -> Future<Result<Feed, TethysError>> {
        return Promise<Result<Feed, TethysError>>().future
    }

    func readAll(of feed: Feed) -> Future<Result<Void, TethysError>> {
        return Promise<Result<Void, TethysError>>().future
    }

    func remove(feed: Feed) -> Future<Result<Void, TethysError>> {
        return Promise<Result<Void, TethysError>>().future
    }


}

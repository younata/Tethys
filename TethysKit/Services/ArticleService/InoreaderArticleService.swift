import Result
import CBGPromise
import FutureHTTP

struct InoreaderArticleService: ArticleService {
    let httpClient: HTTPClient
    let baseURL: URL

    func mark(article: Article, asRead read: Bool) -> Future<Result<Article, TethysError>> {
        return Promise<Result<Article, TethysError>>.resolved(.failure(.unknown))
    }

    func remove(article: Article) -> Future<Result<Void, TethysError>> {
        return Promise<Result<Void, TethysError>>.resolved(.failure(.unknown))
    }

    func authors(of article: Article) -> String {
        return ""
    }

    func date(for article: Article) -> Date {
        return Date()
    }

    func estimatedReadingTime(of article: Article) -> TimeInterval {
        return 0
    }
}

import Result
import CBGPromise

public protocol ArticleService {
    func feed(of article: Article) -> Future<Result<Feed, TethysError>>

    func mark(article: Article, asRead read: Bool) -> Future<Result<Article, TethysError>>
    func remove(article: Article) -> Future<Result<Void, TethysError>>

    func authors(of article: Article) -> String

    func date(for article: Article) -> Date
    func estimatedReadingTime(of article: Article) -> TimeInterval

//    func content(of: Article) -> Future<Result<String, TethysError>>
}

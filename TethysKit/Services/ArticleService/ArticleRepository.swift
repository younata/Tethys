import Result
import CBGPromise

final class ArticleRepository: ArticleService {
    private var articleService: ArticleService

    init(articleService: ArticleService) {
        self.articleService = articleService
    }

    private var markArticleAsReadFutures: [Article: Future<Result<Article, TethysError>>] = [:]
    func mark(article: Article, asRead read: Bool) -> Future<Result<Article, TethysError>> {
        if let future = self.markArticleAsReadFutures[article], future.value == nil { return future }
        let future = self.articleService.mark(article: article, asRead: read)
        self.markArticleAsReadFutures[article] = future
        return future
    }

    private var removeArticleFutures: [Article: Future<Result<Void, TethysError>>] = [:]
    func remove(article: Article) -> Future<Result<Void, TethysError>> {
        if let future = self.removeArticleFutures[article], future.value == nil { return future }
        let future = self.articleService.remove(article: article)
        self.removeArticleFutures[article] = future
        return future
    }

    private var authorsOfArticle: [Article: String] = [:]
    func authors(of article: Article) -> String {
        if let authors = self.authorsOfArticle[article] { return authors }
        let authors = self.articleService.authors(of: article)
        self.authorsOfArticle[article] = authors
        return authors
    }

    private var dateForArticle: [Article: Date] = [:]
    func date(for article: Article) -> Date {
        if let date = self.dateForArticle[article] { return date }
        let date = self.articleService.date(for: article)
        self.dateForArticle[article] = date
        return date
    }

    private var readingTimeOfArticle: [Article: TimeInterval] = [:]
    func estimatedReadingTime(of article: Article) -> TimeInterval {
        if let time = self.readingTimeOfArticle[article] { return time }
        let time = self.articleService.estimatedReadingTime(of: article)
        self.readingTimeOfArticle[article] = time
        return time
    }
}

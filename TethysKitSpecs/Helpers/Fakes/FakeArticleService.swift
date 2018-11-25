import CBGPromise
import Result
import TethysKit

final class FakeArticleService: ArticleService {
    private(set) var feedCalls: [Article] = []
    private(set) var feedPromises: [Promise<Result<Feed, TethysError>>] = []
    func feed(of article: Article) -> Future<Result<Feed, TethysError>> {
        self.feedCalls.append(article)
        let promise = Promise<Result<Feed, TethysError>>()
        self.feedPromises.append(promise)
        return promise.future
    }

    private(set) var markArticleAsReadCalls: [(article: Article, read: Bool)] = []
    private(set) var markArticleAsReadPromises: [Promise<Result<Article, TethysError>>] = []
    func mark(article: Article, asRead read: Bool) -> Future<Result<Article, TethysError>> {
        self.markArticleAsReadCalls.append((article, read))
        let promise = Promise<Result<Article, TethysError>>()
        self.markArticleAsReadPromises.append(promise)
        return promise.future
    }

    private(set) var removeArticleCalls: [Article] = []
    private(set) var removeArticlePromises: [Promise<Result<Void, TethysError>>] = []
    func remove(article: Article) -> Future<Result<Void, TethysError>> {
        self.removeArticleCalls.append(article)
        let promise = Promise<Result<Void, TethysError>>()
        self.removeArticlePromises.append(promise)
        return promise.future
    }

    var authorStub: [Article: String] = [:]
    private(set) var authorsCalls: [Article] = []
    func authors(of article: Article) -> String {
        self.authorsCalls.append(article)
        return self.authorStub[article] ?? ""
    }

    var dateForArticleStub: [Article: Date] = [:]
    private(set) var dateForArticleCalls: [Article] = []
    func date(for article: Article) -> Date {
        self.dateForArticleCalls.append(article)
        return self.dateForArticleStub[article] ?? Date()
    }

    var estimatedReadingTimeStub: [Article: TimeInterval] = [:]
    private(set) var estimatedReadingTimeCalls: [Article] = []
    func estimatedReadingTime(of article: Article) -> TimeInterval {
        self.estimatedReadingTimeCalls.append(article)
        return self.estimatedReadingTimeStub[article] ?? 0
    }
}

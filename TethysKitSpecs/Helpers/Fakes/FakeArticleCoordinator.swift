import CBGPromise

@testable import TethysKit

final class FakeArticleCoordinator: ArticleCoordinator {
    init() {
        super.init(localArticleService: FakeArticleService(), networkArticleServiceProvider: { FakeArticleService() })
    }

    private(set) var markArticleAsReadCalls: [(article: Article, read: Bool)] = []
    private(set) var markArticleAsReadPublishers: [Publisher<Result<Article, TethysError>>] = []
    override func mark(article: Article, asRead read: Bool) -> Subscription<Result<Article, TethysError>> {
        self.markArticleAsReadCalls.append((article, read))
        let publisher = Publisher<Result<Article, TethysError>>()
        self.markArticleAsReadPublishers.append(publisher)
        return publisher.subscription
    }

    private(set) var removeArticleCalls: [Article] = []
    private(set) var removeArticlePromises: [Promise<Result<Void, TethysError>>] = []
    override func remove(article: Article) -> Future<Result<Void, TethysError>> {
        self.removeArticleCalls.append(article)
        let promise = Promise<Result<Void, TethysError>>()
        self.removeArticlePromises.append(promise)
        return promise.future
    }

    var authorStub: [Article: String] = [:]
    private(set) var authorsCalls: [Article] = []
    override func authors(of article: Article) -> String {
        self.authorsCalls.append(article)
        return self.authorStub[article] ?? ""
    }

    var dateForArticleStub: [Article: Date] = [:]
    private(set) var dateForArticleCalls: [Article] = []
    override func date(for article: Article) -> Date {
        self.dateForArticleCalls.append(article)
        return self.dateForArticleStub[article] ?? Date()
    }

    var estimatedReadingTimeStub: [Article: TimeInterval] = [:]
    private(set) var estimatedReadingTimeCalls: [Article] = []
    override func estimatedReadingTime(of article: Article) -> TimeInterval {
        self.estimatedReadingTimeCalls.append(article)
        return self.estimatedReadingTimeStub[article] ?? 0
    }
}

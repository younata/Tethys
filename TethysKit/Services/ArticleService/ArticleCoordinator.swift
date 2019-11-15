import Result
import CBGPromise

public class ArticleCoordinator {
    private let localArticleService: ArticleService
    private let networkArticleService: () -> ArticleService

    init(localArticleService: ArticleService, networkArticleServiceProvider: @escaping () -> ArticleService) {
        self.localArticleService = localArticleService
        self.networkArticleService = networkArticleServiceProvider
    }

    private var markArticleSubscriptions: [MarkArticleCall: Subscription<Result<Article, TethysError>>] = [:]
    public func mark(article: Article, asRead read: Bool) -> Subscription<Result<Article, TethysError>> {
        let call = MarkArticleCall(articleId: article.identifier, read: read)
        if let subscription = self.markArticleSubscriptions[call], subscription.isFinished == false {
            return subscription
        }
        let publisher = Publisher<Result<Article, TethysError>>()
        self.markArticleSubscriptions[call] = publisher.subscription
        let networkFuture = self.networkArticleService().mark(article: article, asRead: read)
        self.localArticleService.mark(article: article, asRead: read).then { localResult in
            publisher.update(with: localResult)

            networkFuture.then { networkResult in
                if localResult.error != nil || networkResult.error != nil {
                    publisher.update(with: networkResult)
                }
                publisher.finish()
                self.markArticleSubscriptions.removeValue(forKey: call)
            }
        }
        return publisher.subscription
    }

    public func remove(article: Article) -> Future<Result<Void, TethysError>> {
        return self.localArticleService.remove(article: article)
    }

    public func authors(of article: Article) -> String {
        return self.localArticleService.authors(of: article)
    }

    public func date(for article: Article) -> Date {
        return self.localArticleService.date(for: article)
    }

    public func estimatedReadingTime(of article: Article) -> TimeInterval {
        return self.localArticleService.estimatedReadingTime(of: article)
    }
}

private struct MarkArticleCall: Hashable {
    let articleId: String
    let read: Bool
}

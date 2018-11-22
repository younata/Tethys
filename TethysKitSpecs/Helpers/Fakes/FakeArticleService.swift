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

    private(set) var authorsCalls: [Article] = []
    var authorStub: (Article) -> String = { _ in "" }
    func authors(of article: Article) -> String {
        self.authorsCalls.append(article)
        return self.authorStub(article)
    }
}

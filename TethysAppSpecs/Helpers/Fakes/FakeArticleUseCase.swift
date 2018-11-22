import TethysKit
import Tethys
import CBGPromise
import Result

class FakeArticleUseCase: ArticleUseCase {
    init() {
    }

    private(set) var articlesByAuthorCallCount : Int = 0
    private var articlesByAuthorArgs : Array<(Author, (AnyCollection<Article>) -> Void)> = []
    func articlesByAuthorArgsForCall(_ callIndex: Int) -> (Author, (AnyCollection<Article>) -> Void) {
        return self.articlesByAuthorArgs[callIndex]
    }
    func articlesByAuthor(_ author: Author, callback: @escaping (AnyCollection<Article>) -> Void) {
        self.articlesByAuthorCallCount += 1
        self.articlesByAuthorArgs.append((author, callback))
    }

    private(set) var readArticleCallCount : Int = 0
    var readArticleStub : ((Article) -> (String))?
    private var readArticleArgs : Array<(Article)> = []
    func readArticleReturns(_ stubbedValues: (String)) {
        self.readArticleStub = {(article: Article) -> (String) in
            return stubbedValues
        }
    }
    func readArticleArgsForCall(_ callIndex: Int) -> (Article) {
        return self.readArticleArgs[callIndex]
    }
    func readArticle(_ article: Article) -> String {
        self.readArticleCallCount += 1
        self.readArticleArgs.append((article))
        return self.readArticleStub!(article)
    }

    private(set) var userActivityForArticleCallCount : Int = 0
    var userActivityForArticleStub : ((Article) -> (NSUserActivity))?
    private var userActivityForArticleArgs : Array<(Article)> = []
    func userActivityForArticleReturns(_ stubbedValues: (NSUserActivity)) {
        self.userActivityForArticleStub = {(article: Article) -> (NSUserActivity) in
            return stubbedValues
        }
    }
    func userActivityForArticleArgsForCall(_ callIndex: Int) -> (Article) {
        return self.userActivityForArticleArgs[callIndex]
    }
    func userActivityForArticle(_ article: Article) -> NSUserActivity {
        self.userActivityForArticleCallCount += 1
        self.userActivityForArticleArgs.append((article))
        return self.userActivityForArticleStub!(article)
    }

    private(set) var toggleArticleReadCallCount : Int = 0
    private var toggleArticleReadArgs : Array<(Article)> = []
    func toggleArticleReadArgsForCall(_ callIndex: Int) -> (Article) {
        return self.toggleArticleReadArgs[callIndex]
    }
    func toggleArticleRead(_ article: Article) {
        self.toggleArticleReadCallCount += 1
        self.toggleArticleReadArgs.append((article))
    }
}

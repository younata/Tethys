import TethysKit
import Tethys
import CBGPromise
import Result

final class FakeArticleUseCase: ArticleUseCase {
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

import UIKit
import TethysKit
import Result
import CBGPromise

public protocol ArticleUseCase {
    func readArticle(_ article: Article) -> String
    func toggleArticleRead(_ article: Article)
}

public final class DefaultArticleUseCase: NSObject, ArticleUseCase {
    private let articleCoordinator: ArticleCoordinator

    public init(articleCoordinator: ArticleCoordinator) {
        self.articleCoordinator = articleCoordinator
        super.init()
    }

    public func readArticle(_ article: Article) -> String {
        _ = self.articleCoordinator.mark(article: article, asRead: true)
        return self.htmlForArticle(article)
    }

    public func toggleArticleRead(_ article: Article) {
        _ = self.articleCoordinator.mark(article: article, asRead: !article.read)
    }

    private lazy var prismJS: String = {
        if let prismURL = Bundle.main.url(forResource: "prism.js", withExtension: "html"),
            let prism = try? String(contentsOf: prismURL) {
                return prism
        }
        return ""
    }()

    private func htmlForArticle(_ article: Article) -> String {
        let prefix: String
        let cssFileName = Theme.articleCSSFileName
        if let cssURL = Bundle.main.url(forResource: cssFileName, withExtension: "css"),
            let css = try? String(contentsOf: cssURL) {
                prefix = "<html><head>" +
                    "<style type=\"text/css\">\(css)</style>" +
                    "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
                    "</head><body>"
        } else {
            prefix = "<html><body>"
        }

        let articleContent = article.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let content = articleContent.isEmpty ? article.summary : articleContent

        let postfix = self.prismJS + "</body></html>"

        return prefix + "<h2>\(article.title)</h2>" + content + postfix
    }
}

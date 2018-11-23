import UIKit
import TethysKit
import Result
import CBGPromise

public protocol ArticleUseCase {
    func articlesByAuthor(_ author: Author, callback: @escaping (AnyCollection<Article>) -> Void)

    func readArticle(_ article: Article) -> String
    func toggleArticleRead(_ article: Article)
}

public final class DefaultArticleUseCase: NSObject, ArticleUseCase {
    private let feedRepository: DatabaseUseCase
    private let themeRepository: ThemeRepository
    private let articleService: ArticleService

    public init(feedRepository: DatabaseUseCase,
                themeRepository: ThemeRepository,
                articleService: ArticleService) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        self.articleService = articleService
        super.init()
    }

    public func articlesByAuthor(_ author: Author, callback: @escaping (AnyCollection<Article>) -> Void) {
        _ = self.feedRepository.feeds().then {
            guard case let Result.success(feeds) = $0 else {
                callback(AnyCollection<Article>([]))
                return
            }
            guard let initial = feeds.first?.articlesArray else { return callback(AnyCollection<Article>([])) }

            let allArticles: DataStoreBackedArray<Article> = feeds[1..<feeds.count].reduce(initial) {
                return $0.combine($1.articlesArray)
            }

            let predicate: NSPredicate
            if let email = author.email {
                predicate = NSPredicate(format: "SUBQUERY(authors, $author, $author.name = %@ AND " +
                    "$author.email = %@) .@count > 0",
                    author.name, email as CVarArg)
            } else {
                predicate = NSPredicate(format: "SUBQUERY(authors, $author, $author.name = %@ AND " +
                    "$author.email = nil) .@count > 0",
                    author.name)
            }

            callback(AnyCollection(allArticles.filterWithPredicate(predicate)))
        }
    }

    public func readArticle(_ article: Article) -> String {
        if !article.read { _ = self.feedRepository.markArticle(article, asRead: true) }
        return self.htmlForArticle(article)
    }

    public func toggleArticleRead(_ article: Article) {
        _ = self.feedRepository.markArticle(article, asRead: !article.read)
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
        let cssFileName = self.themeRepository.articleCSSFileName
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

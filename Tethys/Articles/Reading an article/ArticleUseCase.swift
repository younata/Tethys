import UIKit
import TethysKit
import Result
import CBGPromise

public protocol ArticleUseCase {
    func articlesByAuthor(_ author: Author, callback: @escaping (DataStoreBackedArray<Article>) -> Void)

    func readArticle(_ article: Article) -> String
    func userActivityForArticle(_ article: Article) -> NSUserActivity
    func toggleArticleRead(_ article: Article)

    func relatedArticles(to article: Article) -> [Article]
}

public final class DefaultArticleUseCase: NSObject, ArticleUseCase {
    private let feedRepository: DatabaseUseCase
    private let themeRepository: ThemeRepository

    private var relatedArticles: [Article: Future<Result<[Article], TethysError>>] = [:]

    public init(feedRepository: DatabaseUseCase,
                themeRepository: ThemeRepository) {
        self.feedRepository = feedRepository
        self.themeRepository = themeRepository
        super.init()
    }

    public func articlesByAuthor(_ author: Author, callback: @escaping (DataStoreBackedArray<Article>) -> Void) {
        _ = self.feedRepository.feeds().then {
            guard case let Result.success(feeds) = $0 else {
                callback(DataStoreBackedArray<Article>([]))
                return
            }
            guard let initial = feeds.first?.articlesArray else { return callback(DataStoreBackedArray()) }

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

            callback(allArticles.filterWithPredicate(predicate))
        }
    }

    public func relatedArticles(to article: Article) -> [Article] {
        if self.relatedArticles[article] == nil {
            self.relatedArticles[article] = self.feedRepository.findRelatedArticles(to: article)
        }
        return self.relatedArticles[article]?.value?.value ?? Array(article.relatedArticles)
    }

    public func readArticle(_ article: Article) -> String {
        if !article.read { _ = self.feedRepository.markArticle(article, asRead: true) }
        if self.relatedArticles[article] == nil {
            self.relatedArticles[article] = self.feedRepository.findRelatedArticles(to: article)
        }
        return self.htmlForArticle(article)
    }

    public func toggleArticleRead(_ article: Article) {
        _ = self.feedRepository.markArticle(article, asRead: !article.read)
    }

    private lazy var userActivity: NSUserActivity = {
        let userActivity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
        userActivity.requiredUserInfoKeys = ["feed", "article"]
        userActivity.isEligibleForPublicIndexing = false
        userActivity.isEligibleForSearch = true
        userActivity.delegate = self
        return userActivity
    }()
    fileprivate weak var mostRecentArticle: Article?

    public func userActivityForArticle(_ article: Article) -> NSUserActivity {
        let title: String
        if let feedTitle = article.feed?.title {
            title = "\(feedTitle): \(article.title)"
        } else {
            title = article.title
        }
        self.mostRecentArticle = article
        self.userActivity.title = title
        self.userActivity.webpageURL = article.link
        let authorWords = article.authors.flatMap { $0.description.components(separatedBy: " ") }
        self.userActivity.keywords = Set([article.title, article.summary] + article.flags + authorWords)
        self.userActivity.becomeCurrent()
        self.userActivity.needsSave = true
        return self.userActivity
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

extension DefaultArticleUseCase: NSUserActivityDelegate {
    public func userActivityWillSave(_ userActivity: NSUserActivity) {
        guard let article = self.mostRecentArticle else { return }
        userActivity.userInfo = [
            "feed": article.feed?.title ?? "",
            "article": article.identifier
        ]
    }
}

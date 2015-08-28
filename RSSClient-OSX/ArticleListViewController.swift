import Cocoa
import rNewsKit

public class ArticleListViewController: NSViewController {
    public private(set) var articles = Array<Article>()

    func configure(articles: [Article]) {
        self.view = NSView()
        self.articles = articles
    }
}

import Cocoa
import rNewsKit

public final class ArticleListViewController: NSViewController {
    public private(set) var articles = DataStoreBackedArray<Article>()

    func configure(articles: DataStoreBackedArray<Article>) {
        self.view = NSView()
        self.articles = articles
    }
}

import Cocoa
import rNewsKit

public final class ArticleListViewController: NSViewController {
    public lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.addTableColumn(NSTableColumn())
        return tableView
    }()

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView(forAutoLayout: ())
        scrollView.hasVerticalScroller = true
        scrollView.documentView = self.tableView
        return scrollView
    }()

    private lazy var articlesList: ArticlesList = {
        return ArticlesList(tableView: self.tableView)
    }()

    func configure(articles: DataStoreBackedArray<Article>) {
        self.view = self.scrollView
        self.articlesList.configure(articles: articles) { article in
            print(article)
        }
    }

    public override func viewWillLayout() {
        super.viewWillLayout()

        self.tableView.reloadData()
    }
}

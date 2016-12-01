import Cocoa
import rNewsKit
import Ra

public final class ArticlesList: NSObject {
    fileprivate var articles: DataStoreBackedArray<Article>?
    fileprivate var onSelection: (Article) -> Void = {(_) in }

    fileprivate let tableView: NSTableView

    func configure(articles: DataStoreBackedArray<Article>, onSelection: @escaping (Article) -> Void) {
        self.articles = articles
        self.onSelection = onSelection
        self.tableView.reloadData()
    }

    public init(tableView: NSTableView) {
        self.tableView = tableView

        super.init()

        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.headerView = nil
    }
}

extension ArticlesList: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return self.articles?.count ?? 0
    }
}

extension ArticlesList: NSTableViewDelegate {
    private func heightForArticle(_ article: Article, width: CGFloat) -> CGFloat {
        let height: CGFloat = 16.0
        let titleAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 14)]
        let authorAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 12)]

        let title = NSAttributedString(string: article.title, attributes: titleAttributes)
        let author = NSAttributedString(string: article.authorsString, attributes: authorAttributes)

        let titleBounds = title.boundingRect(with: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: NSStringDrawingOptions.usesFontLeading)
        let authorBounds = author.boundingRect(with: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: NSStringDrawingOptions.usesFontLeading)

        let titleHeight = ceil(titleBounds.width / width) * ceil(titleBounds.height)
        let authorHeight = ceil(authorBounds.width / width) * ceil(authorBounds.height)

        return max(30, height + titleHeight + authorHeight)
    }

    func rowViewForRow(_ row: Int) -> ArticleListView {
        let article = self.articles![row]
        let width = self.tableView.bounds.width
        let articleView = ArticleListView(frame: NSRect(x: 0, y: 0, width: width,
                                                        height: self.heightForArticle(article, width: width - 16)))
        articleView.article = article
        return articleView
    }

    // MARK: NSTableViewDelegate
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return NSView(forAutoLayout: ())
    }

    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return rowViewForRow(row)
    }

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return heightForArticle(articles![row], width: tableView.bounds.width - 16)
    }

    public func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        onSelection(articles![row])
        return false
    }
}

import Cocoa
import rNewsKit

class ArticlesList: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var feeds : [Feed] = [] {
        didSet {
            reload()
        }
    }
    var articles : [Article] = []
    
    weak var tableView: NSTableView? = nil {
        didSet {
            tableView?.setDelegate(self)
            tableView?.setDataSource(self)
            tableView?.headerView = nil
        }
    }
    
    var onSelection : (Article) -> Void = {(_) in }
    
    func reload() {
        let feeds = self.feeds
        dispatch_async(dispatch_get_main_queue()) {
            let articles = feeds.reduce([] as [Article]) { return $0 + $1.articles }
            let newArticles = NSSet(array: articles)
            let oldArticles = NSSet(array: self.articles)
            self.articles = (articles as [Article])
            if newArticles != oldArticles {
                self.articles.sortInPlace {a, b in
                    let da = a.updatedAt ?? a.published
                    let db = b.updatedAt ?? b.published
                    return da.timeIntervalSince1970 > db.timeIntervalSince1970
                }
            }
            if newArticles != oldArticles {
                self.tableView?.reloadData()
            }
        }
    }
    
    func heightForArticle(article: Article, width: CGFloat) -> CGFloat {
        let height : CGFloat = 16.0
        let titleAttributes = [NSFontAttributeName: NSFont.systemFontOfSize(14)]
        let authorAttributes = [NSFontAttributeName: NSFont.systemFontOfSize(12)]
        
        let title = NSAttributedString(string: article.title ?? "", attributes: titleAttributes)
        let author = NSAttributedString(string: article.author ?? "", attributes: authorAttributes)
        
        let titleBounds = title.boundingRectWithSize(NSMakeSize(width, CGFloat.max), options: NSStringDrawingOptions.UsesFontLeading)
        let authorBounds = author.boundingRectWithSize(NSMakeSize(width, CGFloat.max), options: NSStringDrawingOptions.UsesFontLeading)
        
        let titleHeight = ceil(titleBounds.width / width) * ceil(titleBounds.height)
        let authorHeight = ceil(authorBounds.width / width) * ceil(authorBounds.height)
        
        return max(30, height + titleHeight + authorHeight)
    }
    
    func rowViewForRow(row: Int) -> ArticleListView {
        let article = articles[row]
        let width = tableView!.bounds.width
        let articleView = ArticleListView(frame: NSMakeRect(0, 0, width, heightForArticle(article, width: width - 16)))
        articleView.article = article
        return articleView
    }
    
    // MARK: NSTableViewDelegate
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return NSView(forAutoLayout: ())
    }

    func tableView(tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return rowViewForRow(row)
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return heightForArticle(articles[row], width: tableView.bounds.width - 16)
    }
    
    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        onSelection(articles[row])
        return false
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return articles.count
    }
}

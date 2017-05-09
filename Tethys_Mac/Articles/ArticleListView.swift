import Cocoa
import TethysKit

final class ArticleListView: NSTableRowView {
    var article: Article? = nil {
        didSet {
            if let a = article {
                title.string = a.title
                let date = a.updatedAt ?? a.published
                published.string = dateFormatter.string(from: date)
                author.string = a.authorsString

                let hasNotRead = a.read != true
                unread.unread = (hasNotRead ? 1 : 0)
                unreadWidth?.constant = (hasNotRead ? 20 : 0)
            } else {
                title.string = ""
                published.string = ""
                author.string = ""
                unread.unread = 0
            }
        }
    }

    let title = NSTextView(forAutoLayout: ())
    let published = NSTextView(forAutoLayout: ())
    let author = NSTextView(forAutoLayout: ())
    let unread = UnreadCounter()

    var unreadWidth: NSLayoutConstraint?
    var titleHeight: NSLayoutConstraint?
    var authorHeight: NSLayoutConstraint?

    let dateFormatter = DateFormatter()

    override func layout() {
        titleHeight?.constant = ceil(NSAttributedString(string: title.string!,
            attributes: [NSFontAttributeName: title.font!]).size().height)
        super.layout()
    }

    override init(frame: NSRect) {
        super.init(frame: frame)

        unread.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(title)
        self.addSubview(author)
        self.addSubview(published)
        self.addSubview(unread)

        title.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        title.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        titleHeight = title.autoSetDimension(.height, toSize: 18)
        title.font = NSFont.systemFont(ofSize: 14)

        author.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        author.autoPinEdge(.top, to: .bottom, of: title, withOffset: 8)
        author.autoPinEdge(toSuperviewEdge: .bottom, withInset: 4)
        author.font = NSFont.systemFont(ofSize: 12)

        unread.autoPinEdge(toSuperviewEdge: .top)
        unread.autoPinEdge(toSuperviewEdge: .right)
        unread.autoSetDimension(.height, toSize: 20)
        unreadWidth = unread.autoSetDimension(.width, toSize: 20)
        unread.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)

        unread.hideUnreadText = true

        published.autoPinEdge(.right, to: .left, of: unread, withOffset: -8)
        published.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        published.autoPinEdge(.left, to: .right, of: title, withOffset: 8)
        published.autoMatch(.width, to: .width, of: published.superview!, withMultiplier: 0.25)

        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .short
        dateFormatter.timeZone = NSCalendar.current.timeZone

        for tv in [title, author, published] {
            tv.textContainerInset = NSSize.zero
            tv.isEditable = false
        }
        published.font = NSFont.systemFont(ofSize: 12)
        published.alignment = .right
    }

    required init?(coder: NSCoder) {
        fatalError("")
    }
}

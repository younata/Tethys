import UIKit
import WebKit

public class ArticleCell: UITableViewCell, UITextViewDelegate {
    public var article: Article? {
        didSet {
            title.text = article?.title ?? ""
            let publishedDate = article?.updatedAt ?? article?.published ?? NSDate()
            published.text = dateFormatter.stringFromDate(publishedDate) ?? ""
            author.text = article?.author ?? ""
            let hasNotRead = article?.read != true
            unread.unread = hasNotRead ? 1 : 0
            unreadWidth.constant = (hasNotRead ? 30 : 0)
        }
    }

    public let title = UILabel(forAutoLayout: ())
    public let published = UILabel(forAutoLayout: ())
    public let author = UILabel(forAutoLayout: ())
    public let unread = UnreadCounter(forAutoLayout: ())

    private var unreadWidth: NSLayoutConstraint! = nil

    private lazy var dateFormatter: NSDateFormatter = {
        let dateFormatter = NSDateFormatter()

        dateFormatter.timeStyle = .NoStyle
        dateFormatter.dateStyle = .ShortStyle
        dateFormatter.timeZone = NSCalendar.currentCalendar().timeZone

        return dateFormatter
    }()

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(title)
        self.contentView.addSubview(author)
        self.contentView.addSubview(published)
        self.contentView.addSubview(unread)

        title.numberOfLines = 0
        title.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)

        title.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        title.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)

        author.numberOfLines = 0
        author.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)

        author.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        author.autoPinEdge(.Top, toEdge: .Bottom, ofView: title, withOffset: 8)
        author.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4)

        unread.hideUnreadText = true

        unread.autoPinEdgeToSuperviewEdge(.Top)
        unread.autoPinEdgeToSuperviewEdge(.Right)
        unread.autoSetDimension(.Height, toSize: 30)
        unreadWidth = unread.autoSetDimension(.Width, toSize: 30)

        published.textAlignment = .Right
        published.numberOfLines = 0
        published.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)

        published.autoPinEdge(.Right, toEdge: .Left, ofView: unread, withOffset: -8)
        published.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        published.autoPinEdge(.Left, toEdge: .Right, ofView: title, withOffset: 8)
        published.autoMatchDimension(.Width, toDimension: .Width,
            ofView: published.superview, withMultiplier: 0.25)
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("")
    }

    public func textView(textView: UITextView, shouldInteractWithURL URL: NSURL,
        inRange characterRange: NSRange) -> Bool {
        return false
    }
}

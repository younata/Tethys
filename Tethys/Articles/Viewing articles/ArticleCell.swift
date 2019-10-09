import UIKit
import TethysKit

public final class ArticleCell: UITableViewCell {
    public let title = UILabel(forAutoLayout: ())
    public let published = UILabel(forAutoLayout: ())
    public let author = UILabel(forAutoLayout: ())
    public let unread = UnreadCounter(forAutoLayout: ())
    public let readingTime = UILabel(forAutoLayout: ())

    var unreadWidth: NSLayoutConstraint! = nil

    fileprivate let backgroundColorView = UIView()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self.title)
        self.contentView.addSubview(self.author)
        self.contentView.addSubview(self.published)
        self.contentView.addSubview(self.unread)
        self.contentView.addSubview(self.readingTime)

        self.title.numberOfLines = 0
        self.title.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)

        self.title.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        self.title.autoPinEdge(toSuperviewEdge: .top, withInset: 4)

        self.author.numberOfLines = 0
        self.author.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)

        self.author.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        self.author.autoPinEdge(.top, to: .bottom, of: self.title, withOffset: 8)

        self.readingTime.numberOfLines = 0
        self.readingTime.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)

        self.readingTime.autoPinEdge(toSuperviewEdge: .leading, withInset: 8)
        self.readingTime.autoPinEdge(toSuperviewEdge: .bottom, withInset: 4)
        self.readingTime.autoPinEdge(.top, to: .bottom, of: self.author, withOffset: 4)

        self.unread.hideUnreadText = true

        self.unread.autoPinEdge(toSuperviewEdge: .top)
        self.unread.autoPinEdge(toSuperviewEdge: .right)
        self.unread.autoSetDimension(.height, toSize: 30)
        self.unreadWidth = unread.autoSetDimension(.width, toSize: 30)

        self.published.textAlignment = .right
        self.published.numberOfLines = 0
        self.published.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)

        self.published.autoPinEdge(.right, to: .left, of: unread, withOffset: -8)
        self.published.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        self.published.autoPinEdge(.left, to: .right, of: title, withOffset: 8)
        self.published.autoMatch(.width, to: .width,
            of: self.contentView, withMultiplier: 0.25)

        self.multipleSelectionBackgroundView  = self.backgroundColorView
        self.selectedBackgroundView = self.backgroundColorView

        self.isAccessibilityElement = true
        self.accessibilityTraits = [.button]
        self.accessibilityLabel = NSLocalizedString("ArticleCell_Accessibility_Label", comment: "")

        self.applyTheme()
    }

    public required init(coder aDecoder: NSCoder) { fatalError() }

    private func applyTheme() {
        self.title.textColor = Theme.textColor
        self.published.textColor = Theme.textColor
        self.author.textColor = Theme.textColor
        self.readingTime.textColor = Theme.textColor
        self.backgroundColorView.backgroundColor = Theme.overlappingBackgroundColor
        self.unread.triangleColor = Theme.highlightColor

        self.backgroundColor = Theme.backgroundColor
    }
}

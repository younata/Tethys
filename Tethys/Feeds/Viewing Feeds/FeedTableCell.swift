import UIKit
import PureLayout
import TethysKit

public final class FeedTableCell: UITableViewCell {
    public var feed: Feed? = nil {
        didSet {
            if let f = feed {
                self.nameLabel.text = f.displayTitle
                self.summaryLabel.text = f.displaySummary
                self.unreadCounter.unread = f.unreadCount

                let unreadCountString = String.localizedStringWithFormat(NSLocalizedString(
                    "FeedsTableViewController_Accessibility_Cell_UnreadArticles",
                    comment: ""
                ), f.unreadCount)
                self.accessibilityValue = "\(f.displayTitle). \(unreadCountString)"
            } else {
                self.nameLabel.text = ""
                self.summaryLabel.text = ""
                self.unreadCounter.unread = 0
            }
            if let image = feed?.image {
                self.iconView.image = image
                let scaleRatio = 60 / image.size.width
                self.iconWidth.constant = 60
                self.iconHeight.constant = image.size.height * scaleRatio
            } else {
                self.iconView.image = nil
                self.iconWidth.constant = 45
                self.iconHeight.constant = 0
            }
        }
    }

    public let nameLabel = UILabel(forAutoLayout: ())
    public let summaryLabel = UILabel(forAutoLayout: ())
    public let unreadCounter = UnreadCounter(frame: CGRect.zero)
    public let iconView = UIImageView(forAutoLayout: ())

    fileprivate let backgroundColorView = UIView()

    public private(set) var iconWidth: NSLayoutConstraint!
    public private(set) var iconHeight: NSLayoutConstraint!

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.nameLabel.numberOfLines = 0
        self.nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)

        self.summaryLabel.numberOfLines = 0
        self.summaryLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)

        self.iconView.contentMode = .scaleAspectFit

        self.unreadCounter.hideUnreadText = false
        self.unreadCounter.translatesAutoresizingMaskIntoConstraints = false

        self.contentView.addSubview(self.nameLabel)
        self.contentView.addSubview(self.summaryLabel)
        self.contentView.addSubview(self.iconView)
        self.contentView.addSubview(self.unreadCounter)

        self.nameLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        self.nameLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        self.nameLabel.autoPinEdge(.right, to: .left, of: self.iconView, withOffset: -8)

        self.summaryLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 4, relation: .greaterThanOrEqual)
        self.summaryLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        self.summaryLabel.autoPinEdge(.right, to: .left, of: self.iconView, withOffset: -8)
        self.summaryLabel.autoPinEdge(.top, to: .bottom, of: self.nameLabel, withOffset: 8,
            relation: .greaterThanOrEqual)

        self.iconView.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
        self.iconView.autoPinEdge(toSuperviewEdge: .right)
        self.iconView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
        self.iconView.autoAlignAxis(toSuperviewAxis: .horizontal)
        self.iconWidth = self.iconView.autoSetDimension(.width, toSize: 45, relation: .lessThanOrEqual)
        self.iconHeight = self.iconView.autoSetDimension(.height, toSize: 0, relation: .lessThanOrEqual)

        self.unreadCounter.autoPinEdge(toSuperviewEdge: .top)
        self.unreadCounter.autoPinEdge(toSuperviewEdge: .right)
        self.unreadCounter.autoSetDimension(.height, toSize: 45)
        self.unreadCounter.autoMatch(.width, to: .height, of: self.unreadCounter)
        self.unreadCounter.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)

        self.selectedBackgroundView = self.backgroundColorView
        self.isAccessibilityElement = true
        self.accessibilityLabel = NSLocalizedString("FeedsTableViewController_Accessibility_Cell_Label", comment: "")
        self.accessibilityTraits = [.button]

        self.applyTheme()
    }

    public required init?(coder aDecoder: NSCoder) { fatalError() }

    private func applyTheme() {
        self.nameLabel.textColor = Theme.textColor
        self.summaryLabel.textColor = Theme.textColor

        self.backgroundColorView.backgroundColor = Theme.overlappingBackgroundColor
        self.unreadCounter.triangleColor = Theme.highlightColor

        self.backgroundColor = Theme.backgroundColor
    }

    public override func prepareForReuse() {
        super.prepareForReuse()

        self.nameLabel.text = ""
        self.summaryLabel.text = ""
        self.unreadCounter.unread = 0

        self.iconView.image = nil

        self.accessibilityValue = nil
    }
}

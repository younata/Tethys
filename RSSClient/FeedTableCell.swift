import UIKit
import PureLayout
import rNewsKit

public class FeedTableCell: UITableViewCell {
    public var feed: Feed? = nil {
        didSet {
            if let f = feed {
                self.nameLabel.text = f.displayTitle
                self.summaryLabel.text = f.displaySummary
                self.unreadCounter.unread = UInt(f.unreadArticles().count)
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

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public let nameLabel = UILabel(forAutoLayout: ())
    public let summaryLabel = UILabel(forAutoLayout: ())
    public let unreadCounter = UnreadCounter(frame: CGRectZero)
    public let iconView = UIImageView(forAutoLayout: ())

    public private(set) var iconWidth: NSLayoutConstraint!

    public private(set) var iconHeight: NSLayoutConstraint!

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.nameLabel.numberOfLines = 0
        self.nameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)

        self.summaryLabel.numberOfLines = 0
        self.summaryLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)

        self.iconView.contentMode = .ScaleAspectFit

        self.unreadCounter.hideUnreadText = false
        self.unreadCounter.translatesAutoresizingMaskIntoConstraints = false

        self.contentView.addSubview(self.nameLabel)
        self.contentView.addSubview(self.summaryLabel)
        self.contentView.addSubview(self.iconView)
        self.contentView.addSubview(self.unreadCounter)

        self.nameLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        self.nameLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        self.nameLabel.autoPinEdge(.Right, toEdge: .Left, ofView: self.iconView, withOffset: -8)

        self.summaryLabel.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4, relation: .GreaterThanOrEqual)
        self.summaryLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        self.summaryLabel.autoPinEdge(.Right, toEdge: .Left, ofView: self.iconView, withOffset: -8)
        self.summaryLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.nameLabel, withOffset: 8,
            relation: .GreaterThanOrEqual)

        self.iconView.autoPinEdgeToSuperviewEdge(.Top, withInset: 0, relation: .GreaterThanOrEqual)
        self.iconView.autoPinEdgeToSuperviewEdge(.Right)
        self.iconView.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
        self.iconView.autoAlignAxisToSuperviewAxis(.Horizontal)
        self.iconWidth = self.iconView.autoSetDimension(.Width, toSize: 45, relation: .LessThanOrEqual)
        self.iconHeight = self.iconView.autoSetDimension(.Height, toSize: 0, relation: .LessThanOrEqual)

        self.unreadCounter.autoPinEdgeToSuperviewEdge(.Top)
        self.unreadCounter.autoPinEdgeToSuperviewEdge(.Right)
        self.unreadCounter.autoSetDimension(.Height, toSize: 45)
        self.unreadCounter.autoMatchDimension(.Width, toDimension: .Height, ofView: self.unreadCounter)
        self.unreadCounter.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError() }
}

extension FeedTableCell: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.nameLabel.textColor = self.themeRepository?.textColor
        self.summaryLabel.textColor = self.themeRepository?.textColor

        self.backgroundColor = self.themeRepository?.backgroundColor
    }
}

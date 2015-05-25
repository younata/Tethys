import UIKit
import PureLayout_iOS

class FeedTableCell: UITableViewCell {
    var feed: Feed? = nil {
        didSet {
            if let f = feed {
                nameLabel.text = f.title
                summaryLabel.text = f.summary
                unreadCounter.unread = UInt(filter(f.articles, {return $0.read == false}).count)
            } else {
                nameLabel.text = ""
                summaryLabel.text = ""
                unreadCounter.unread = 0
            }
            if let image = feed?.image {
                iconView.image = image
                let scaleRatio = 60 / image.size.width
                iconWidth.constant = 60
                iconHeight.constant = image.size.height * scaleRatio
            } else {
                iconView.image = nil
                iconWidth.constant = 45
                iconHeight.constant = 0
            }
        }
    }

    lazy var nameLabel : UILabel = {
        let label = UILabel(forAutoLayout: ())

        label.numberOfLines = 0
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)

        self.contentView.addSubview(label)

        label.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        label.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        label.autoPinEdge(.Right, toEdge: .Left, ofView: self.iconView, withOffset: -8)
        return label
    }()

    lazy var summaryLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())

        label.numberOfLines = 0
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)

        self.contentView.addSubview(label)

        label.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4, relation: .GreaterThanOrEqual)
        label.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        label.autoPinEdge(.Right, toEdge: .Left, ofView: self.iconView, withOffset: -8)
        label.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.nameLabel, withOffset: 8, relation: .GreaterThanOrEqual)

        return label
    }()

    lazy var unreadCounter: UnreadCounter = {
        let counter = UnreadCounter(frame: CGRectZero)

        counter.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.contentView.addSubview(counter)

        counter.autoPinEdgeToSuperviewEdge(.Top)
        counter.autoPinEdgeToSuperviewEdge(.Right)
        counter.autoSetDimension(.Height, toSize: 45)
        counter.autoMatchDimension(.Width, toDimension: .Height, ofView: counter)
        counter.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)

        return counter
    }()

    lazy var iconView: UIImageView = {
        let imageView = UIImageView(forAutoLayout: ())

        imageView.contentMode = .ScaleAspectFit

        self.contentView.addSubview(imageView)

        imageView.autoPinEdgeToSuperviewEdge(.Top)
        imageView.autoPinEdgeToSuperviewEdge(.Right)
        imageView.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)

        return imageView
    }()

    lazy var iconWidth: NSLayoutConstraint = {
        return self.iconView.autoSetDimension(.Width, toSize: 45)
    }()

    lazy var iconHeight: NSLayoutConstraint = {
        return self.iconView.autoSetDimension(.Height, toSize: 0)
    }()

    var dataManager: DataManager? = nil
}

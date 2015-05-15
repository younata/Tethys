import UIKit

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
                iconWidth?.constant = 60
                iconHeight?.constant = image.size.height * scaleRatio
            } else {
                iconView.image = nil
                iconWidth?.constant = 45
                iconHeight?.constant = 0
            }
        }
    }
    
    var dataManager : DataManager? = nil
    
    let nameLabel = UILabel(forAutoLayout: ())
    let summaryLabel = UILabel(forAutoLayout: ())
    let unreadCounter = UnreadCounter(frame: CGRectZero)
    let iconView = UIImageView(forAutoLayout: ())
    
    var iconWidth : NSLayoutConstraint? = nil
    var iconHeight : NSLayoutConstraint? = nil
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        unreadCounter.setTranslatesAutoresizingMaskIntoConstraints(false)
        
        self.contentView.addSubview(nameLabel)
        self.contentView.addSubview(summaryLabel)
        self.contentView.addSubview(iconView)
        self.contentView.addSubview(unreadCounter)
        
        unreadCounter.autoPinEdgeToSuperviewEdge(.Top)
        unreadCounter.autoPinEdgeToSuperviewEdge(.Right)
        unreadCounter.autoSetDimension(.Height, toSize: 45)
        unreadCounter.autoMatchDimension(.Width, toDimension: .Height, ofView: unreadCounter)
        unreadCounter.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
        
        iconView.autoPinEdgeToSuperviewEdge(.Top)
        iconView.autoPinEdgeToSuperviewEdge(.Right)
        iconView.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 0, relation: .GreaterThanOrEqual)
        iconWidth = iconView.autoSetDimension(.Width, toSize: 45)
        iconHeight = iconView.autoSetDimension(.Height, toSize: 0)
        
        iconView.contentMode = .ScaleAspectFit
        
        nameLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        nameLabel.autoPinEdge(.Right, toEdge: .Left, ofView: iconView, withOffset: -8)
        nameLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        
        nameLabel.numberOfLines = 0
        nameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        summaryLabel.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 4, relation: .GreaterThanOrEqual)
        summaryLabel.autoPinEdge(.Right, toEdge: .Left, ofView: iconView, withOffset: -8)
        summaryLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: nameLabel, withOffset: 8, relation: .GreaterThanOrEqual)
        summaryLabel.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        
        summaryLabel.numberOfLines = 0
        summaryLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
    }
    
    required init(coder: NSCoder) {
        fatalError("NSCoding not supported")
    }
}

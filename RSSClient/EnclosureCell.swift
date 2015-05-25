import UIKit

class EnclosureCell: UICollectionViewCell {
    var enclosure: CoreDataEnclosure? = nil {
        didSet {
            nameLabel.text = enclosure?.url?.lastPathComponent ?? ""
            let text = NSAttributedString(string: nameLabel.text!,
                attributes: [NSFontAttributeName: nameLabel.font])
            let size = text.boundingRectWithSize(CGSizeMake(120, CGFloat.max),
                options: .UsesFontLeading, context: nil).size
            nameHeight?.constant = ceil(size.height)
            progressLayer.progress = 0

            placeholderLabel.text = enclosure?.url?.pathExtension ?? ""
        }
    }

    let nameLabel = UILabel(forAutoLayout: ())
    let loadingBar = UIView(forAutoLayout: ())
    let progressLayer = CircularProgressLayer()

    let placeholderLabel = UILabel(forAutoLayout: ())

    var nameHeight: NSLayoutConstraint? = nil

    required init(coder: NSCoder) {
        fatalError("")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.contentView.addSubview(loadingBar)
        let barInsets = UIEdgeInsetsMake(4, 4, 0, 4)
        loadingBar.autoPinEdgesToSuperviewEdgesWithInsets(barInsets, excludingEdge: .Bottom)
        loadingBar.autoSetDimension(.Width, toSize: 60)
        loadingBar.autoMatchDimension(.Height, toDimension: .Width, ofView: loadingBar)
        loadingBar.layer.addSublayer(progressLayer)
        loadingBar.backgroundColor = UIColor.lightGrayColor()
        progressLayer.strokeColor = UIColor.clearColor().CGColor
        progressLayer.fillColor = UIColor.blackColor().colorWithAlphaComponent(0.5).CGColor

        loadingBar.addSubview(placeholderLabel)
        placeholderLabel.autoCenterInSuperview()
        placeholderLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)

        self.contentView.addSubview(nameLabel)
        let nameInsets = UIEdgeInsetsMake(0, 4, 4, 4)
        nameLabel.autoPinEdgesToSuperviewEdgesWithInsets(nameInsets, excludingEdge: .Top)
        nameHeight = nameLabel.autoSetDimension(.Height, toSize: 30)
        nameLabel.autoSetDimension(.Width, toSize: 60)
        nameLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: loadingBar, withOffset: 8)
        nameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
    }
}

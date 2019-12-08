import UIKit
import TethysKit
import PureLayout

final class ArticleListHeaderView: UIView {
    let summary = UILabel(forAutoLayout: ())
    let iconView = UIImageView(forAutoLayout: ())

    private let footer = UIView(forAutoLayout: ())

    private var iconWidth: NSLayoutConstraint!
    private var iconHeight: NSLayoutConstraint!

    func configure(summary: String, image: UIImage?) {
        self.summary.text = summary
        if let image = image {
            self.iconView.isHidden = false
            self.iconView.image = image
            let scaleRatio = 60 / image.size.width
            self.iconWidth.constant = 60
            self.iconHeight.constant = image.size.height * scaleRatio
        } else {
            self.iconView.isHidden = true
            self.iconView.image = nil
            self.iconWidth.constant = 0
            self.iconHeight.constant = 0
        }
        self.accessibilityValue = summary
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        let stackView = UIStackView(arrangedSubviews: [self.summary, self.iconView])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .firstBaseline
        stackView.distribution = .fillProportionally

        self.addSubview(stackView)
        self.addSubview(self.footer)

        self.summary.numberOfLines = 0
        self.summary.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)

        self.iconView.contentMode = .scaleAspectFit

        stackView.autoPinEdge(toSuperviewEdge: .leading, withInset: 8).priority = .defaultHigh
        stackView.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0)

        self.iconWidth = self.iconView.autoSetDimension(.width, toSize: 0, relation: .lessThanOrEqual)
        self.iconHeight = self.iconView.autoSetDimension(.height, toSize: 0, relation: .lessThanOrEqual)

        self.footer.autoPinEdge(.top, to: .bottom, of: stackView, withOffset: 8)
        self.footer.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
                                                 excludingEdge: .top)
        self.footer.autoSetDimension(.height, toSize: 2)

        self.isAccessibilityElement = true
        self.accessibilityTraits = [.staticText]
        self.accessibilityLabel = NSLocalizedString("ArticleListController_HeaderCell_Accessibility_Label",
                                                    comment: "")

        self.applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyTheme() {
        self.summary.textColor = Theme.textColor
        self.footer.backgroundColor = Theme.separatorColor

        self.backgroundColor = Theme.backgroundColor
    }
}

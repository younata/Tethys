import UIKit
import PureLayout

public final class ExplanationView: UIView {
    public var title: String {
        get { return self.titleLabel.text ?? "" }
        set { self.titleLabel.text = newValue }
    }

    public var detail: String {
        get { return self.detailLabel.text ?? "" }
        set { self.detailLabel.text = newValue }
    }

    private let titleLabel = UILabel(forAutoLayout: ())
    private let detailLabel = UILabel(forAutoLayout: ())

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 0
        self.titleLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)

        self.detailLabel.textAlignment = .center
        self.detailLabel.numberOfLines = 0
        self.detailLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        self.addSubview(self.titleLabel)
        self.addSubview(self.detailLabel)

        self.titleLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 20, left: 20, bottom: 0, right: 20),
            excludingEdge: .bottom)
        self.detailLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 8, bottom: 8, right: 8),
            excludingEdge: .top)

        self.detailLabel.autoPinEdge(.top, to: .bottom, of: self.titleLabel, withOffset: 8)

        self.layer.cornerRadius = 4

        self.isAccessibilityElement = true
        self.isUserInteractionEnabled = false
        self.accessibilityTraits = [.staticText]

        self.applyTheme()
    }

    public required init?(coder aDecoder: NSCoder) { fatalError() }

    private func applyTheme() {
        self.titleLabel.textColor = Theme.textColor
        self.detailLabel.textColor = Theme.textColor
    }
}

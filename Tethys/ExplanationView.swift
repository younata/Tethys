import UIKit
import PureLayout

@IBDesignable
public final class ExplanationView: UIView {
    @IBInspectable public var title: String {
        get { return self.titleLabel.text ?? "" }
        set { self.titleLabel.text = newValue }
    }

    @IBInspectable public var detail: String {
        get { return self.detailLabel.text ?? "" }
        set { self.detailLabel.text = newValue }
    }

    internal var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    fileprivate let titleLabel = UILabel(forAutoLayout: ())
    fileprivate let detailLabel = UILabel(forAutoLayout: ())

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

        self.layer.cornerRadius = 5
    }

    public required init?(coder aDecoder: NSCoder) { fatalError() }
}

extension ExplanationView: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.titleLabel.textColor = self.themeRepository?.textColor
        self.detailLabel.textColor = self.themeRepository?.textColor
    }
}

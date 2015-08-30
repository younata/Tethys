import UIKit
import PureLayout_iOS

public class ExplanationView: UIView {

    public var title: String {
        get {
            return self.titleLabel.text ?? ""
        }
        set {
            self.titleLabel.text = newValue
        }
    }

    public var detail: String {
        get {
            return self.detailLabel.text ?? ""
        }
        set {
            self.detailLabel.text = newValue
        }
    }

    internal var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    private let titleLabel = UILabel(forAutoLayout: ())

    private let detailLabel = UILabel(forAutoLayout: ())

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.titleLabel.textAlignment = .Center
        self.titleLabel.numberOfLines = 0
        self.titleLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)

        self.detailLabel.textAlignment = .Center
        self.detailLabel.numberOfLines = 0
        self.detailLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        self.addSubview(self.titleLabel)
        self.addSubview(self.detailLabel)

        self.titleLabel.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsets(top: 20, left: 20, bottom: 0, right: 20), excludingEdge: .Bottom)
        self.detailLabel.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsets(top: 0, left: 8, bottom: 8, right: 8), excludingEdge: .Top)

        self.detailLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.titleLabel, withOffset: 8)

        self.layer.cornerRadius = 5
    }

    public convenience init(forAutoLayout: ()) {
        self.init(frame: CGRectZero)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}

extension ExplanationView: ThemeRepositorySubscriber {
    public func didChangeTheme() {
        self.titleLabel.textColor = self.themeRepository?.textColor
        self.detailLabel.textColor = self.themeRepository?.textColor
    }
}

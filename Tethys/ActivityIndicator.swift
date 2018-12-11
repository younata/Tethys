import UIKit
import PureLayout

public final class ActivityIndicator: UIView {
    public var message: String { return self.label.text ?? "" }

    public func configure(message: String) {
        self.label.text = message
        self.activityIndicator.startAnimating()
        self.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    }

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .white)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(indicator)
        indicator.autoPinEdge(toSuperviewEdge: .leading)
        indicator.autoPinEdge(toSuperviewEdge: .trailing)
        indicator.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
        return indicator
    }()

    private lazy var label: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.textColor = UIColor.white
        self.addSubview(label)
        label.autoCenterInSuperview()
        label.autoPinEdge(toSuperviewMargin: .leading)
        label.autoPinEdge(toSuperviewMargin: .trailing)
        label.autoPinEdge(.top, to: .bottom, of: self.activityIndicator, withOffset: 8)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
}

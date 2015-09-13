import UIKit
import PureLayout

public class ActivityIndicator: UIView {
    public var message: String {
        return self.label.text ?? ""
    }

    public func configureWithMessage(message: String) {
        self.label.text = message
        self.activityIndicator.startAnimating()
        self.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.7)
    }

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .White)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(indicator)
        indicator.autoPinEdgeToSuperviewEdge(.Leading)
        indicator.autoPinEdgeToSuperviewEdge(.Trailing)
        indicator.autoPinEdgeToSuperviewEdge(.Top, withInset: 0, relation: .GreaterThanOrEqual)
        return indicator
    }()

    private lazy var label: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.textColor = UIColor.whiteColor()
        self.addSubview(label)
        label.autoCenterInSuperview()
        label.autoPinEdgeToSuperviewMargin(.Leading)
        label.autoPinEdgeToSuperviewMargin(.Trailing)
        label.autoPinEdge(.Top, toEdge: .Bottom, ofView: self.activityIndicator, withOffset: 8)
        label.textAlignment = .Center
        label.numberOfLines = 0
        return label
    }()
}

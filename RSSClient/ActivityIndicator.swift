import UIKit
import PureLayout_iOS

public class ActivityIndicator: UIView {
    public var message: String {
        return self.label.text ?? ""
    }

    public func configureWithMessage(message: String) {
        label.text = message
        activityIndicator.startAnimating()
        backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.7)
    }

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .White)
        indicator.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.addSubview(indicator)
        indicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        indicator.autoPinEdge(.Bottom, toEdge: .Top, ofView: self.label)
        return indicator
    }()

    private lazy var label: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.textColor = UIColor.whiteColor()
        self.addSubview(label)
        label.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        return label
    }()
}

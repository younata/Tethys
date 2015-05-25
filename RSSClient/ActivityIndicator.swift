import UIKit
import PureLayout_iOS

class ActivityIndicator: UIView {
    var message : String {
        return self.label.text ?? ""
    }

    func configureWithMessage(message: String) {
        label.text = message
        activityIndicator.startAnimating()
        backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.7)
    }

    private lazy var activityIndicator : UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .White)
        activityIndicator.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.addSubview(activityIndicator)
        activityIndicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Bottom)
        activityIndicator.autoPinEdge(.Bottom, toEdge: .Top, ofView: self.label)
        return activityIndicator
    }()

    private lazy var label : UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.textColor = UIColor.whiteColor()
        self.addSubview(label)
        label.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)
        return label
    }()
}

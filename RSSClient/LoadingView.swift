import UIKit

class LoadingView: UIView {

    var msg: String = "" {
        didSet {
            label.text = msg
        }
    }

    private let label = UILabel(forAutoLayout: ())

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor(white: 0.25, alpha: 0.5)

        let displayView = UIView(forAutoLayout: ())
        self.addSubview(displayView)

        displayView.autoCenterInSuperview()
        displayView.autoPinEdgeToSuperviewEdge(.Right, withInset: 8, relation: .GreaterThanOrEqual)
        displayView.autoPinEdgeToSuperviewEdge(.Left, withInset: 8, relation: .GreaterThanOrEqual)
        displayView.layer.cornerRadius = 5
        displayView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        let effect = UIVibrancyEffect(forBlurEffect: UIBlurEffect(style: .Dark))
        displayView.addSubview(UIVisualEffectView(effect: effect))

        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .White)
        indicator.setTranslatesAutoresizingMaskIntoConstraints(false)
        displayView.addSubview(indicator)

        indicator.autoAlignAxisToSuperviewAxis(.Vertical)
        indicator.autoPinEdgeToSuperviewEdge(.Top, withInset: 8)
        indicator.startAnimating()

        displayView.addSubview(label)
        let labelInsets = UIEdgeInsetsMake(0, 8, 8, 8)
        label.autoPinEdgesToSuperviewEdgesWithInsets(labelInsets, excludingEdge: .Top)
        label.autoPinEdge(.Top, toEdge: .Bottom, ofView: indicator, withOffset: 4)
        label.textColor = UIColor.whiteColor()
        label.numberOfLines = 0
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

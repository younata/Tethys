import UIKit
import PureLayout_iOS

public class ValidatorView: UIView {

    public enum ValidatorState {
        case Invalid
        case Valid
        case Validating
    }

    public private(set) var state: ValidatorState = .Invalid

    public private(set) lazy var progressIndicator: UIActivityIndicatorView = {
        let progressIndicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(progressIndicator)

        progressIndicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        return progressIndicator
    }()

    private let checkMark = CAShapeLayer()

    public func beginValidating() {
        state = .Validating
        checkMark.removeFromSuperlayer()

        progressIndicator.hidden = false
        progressIndicator.alpha = 1
        progressIndicator.startAnimating()
    }

    public func endValidating(valid: Bool = true) {
        state = valid ? .Valid : .Invalid

        progressIndicator.stopAnimating()

        if state == .Valid {
            checkMark.path = checkmarkPath(self.frame, checkmarkWidth: 10)
            checkMark.fillColor = UIColor.redColor().CGColor
        } else if state == .Invalid {
            checkMark.path = xPath(self.frame, xWidth: 10)
            checkMark.fillColor = UIColor.darkGreenColor().CGColor
        }

        UIView.animateWithDuration(0.2, animations: {
            self.progressIndicator.alpha = 0
        }, completion: {(completion: Bool) in
            self.progressIndicator.hidden = true
            self.progressIndicator.alpha = 1
            self.layer.addSublayer(self.checkMark)
        })
    }

    private func checkmarkPath(frame: CGRect, checkmarkWidth: CGFloat) -> CGPath {
        let path = CGPathCreateMutable()

        let w = frame.width
        let h = frame.height

        let cm = checkmarkWidth / 2

        CGPathMoveToPoint(path, nil, 0, h * (2.0 / 3.0) + cm)
        CGPathAddLineToPoint(path, nil, w / 3.0, h)
        CGPathAddLineToPoint(path, nil, w, cm)

        CGPathAddLineToPoint(path, nil, w, -cm)
        CGPathAddLineToPoint(path, nil, w / 3.0, h - cm)
        CGPathAddLineToPoint(path, nil, 0, h * (2.0 / 3.0) - cm)
        CGPathAddLineToPoint(path, nil, 0, h * (2.0 / 3.0) + cm)

        return path
    }

    private func xPath(frame: CGRect, xWidth: CGFloat) -> CGPath {
        let path = CGPathCreateMutable()

        let w = frame.width
        let h = frame.height

        let xm = xWidth / 2

        CGPathMoveToPoint(path, nil, 0, h / 2 + xm)
        CGPathAddLineToPoint(path, nil, w / 2 - xm, h / 2 + xm)
        CGPathAddLineToPoint(path, nil, w / 2 - xm, h)
        CGPathAddLineToPoint(path, nil, w / 2 + xm, h)
        CGPathAddLineToPoint(path, nil, w / 2 + xm, h / 2 + xm)
        CGPathAddLineToPoint(path, nil, w, h / 2 + xm)

        CGPathAddLineToPoint(path, nil, w, h / 2 - xm)
        CGPathAddLineToPoint(path, nil, w / 2 + xm, h / 2 - xm)
        CGPathAddLineToPoint(path, nil, w / 2 + xm, 0)
        CGPathAddLineToPoint(path, nil, w / 2 - xm, 0)
        CGPathAddLineToPoint(path, nil, w / 2 - xm, h / 2 - xm)
        CGPathAddLineToPoint(path, nil, 0, h / 2 - xm)
        CGPathAddLineToPoint(path, nil, 0, h / 2 + xm)

        return path
    }
}

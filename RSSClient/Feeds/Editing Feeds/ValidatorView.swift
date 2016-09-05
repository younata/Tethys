import UIKit
import PureLayout

public final class ValidatorView: UIView {
    public enum ValidatorState {
        case invalid
        case valid
        case validating
    }

    public private(set) var state: ValidatorState = .invalid

    public private(set) lazy var progressIndicator: UIActivityIndicatorView = {
        let progressIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(progressIndicator)

        progressIndicator.autoPinEdgesToSuperviewEdges(with: UIEdgeInsetsZero)
        return progressIndicator
    }()

    private let checkMark = CAShapeLayer()

    public func beginValidating() {
        state = .validating
        checkMark.removeFromSuperlayer()

        progressIndicator.isHidden = false
        progressIndicator.alpha = 1
        progressIndicator.startAnimating()
    }

    public func endValidating(_ valid: Bool = true) {
        state = valid ? .valid : .invalid

        progressIndicator.stopAnimating()

        if state == .valid {
            checkMark.path = checkmarkPath(self.frame, checkmarkWidth: 10)
            checkMark.fillColor = UIColor.red.cgColor
        } else if state == .invalid {
            checkMark.path = xPath(self.frame, xWidth: 10)
            checkMark.fillColor = UIColor.darkGreen().cgColor
        }

        UIView.animate(withDuration: 0.2, animations: {
            self.progressIndicator.alpha = 0
        }, completion: {(completion: Bool) in
            self.progressIndicator.isHidden = true
            self.progressIndicator.alpha = 1
            self.layer.addSublayer(self.checkMark)
        })
    }

    private func checkmarkPath(_ frame: CGRect, checkmarkWidth: CGFloat) -> CGPath {
        let path = CGMutablePath()

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

    private func xPath(_ frame: CGRect, xWidth: CGFloat) -> CGPath {
        let path = CGMutablePath()

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

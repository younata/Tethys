import UIKit
import PureLayout_iOS

class ValidatorView: UIView {
    
    enum ValidatorState {
        case Invalid
        case Valid
        case Validating
    }
    
    var state : ValidatorState = .Invalid
    
    let progressIndicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
    
    let checkMark = CAShapeLayer()
    
    func beginValidating() {
        state = .Validating
        checkMark.removeFromSuperlayer()
        
        progressIndicator.hidden = false
        progressIndicator.alpha = 1
        progressIndicator.startAnimating()
    }
    
    func endValidating(valid: Bool = true) {
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
    
    func checkmarkPath(frame: CGRect, checkmarkWidth: CGFloat) -> CGPath {
        let path = CGPathCreateMutable()
        
        let x = frame.origin.x
        let y = frame.origin.y
        let w = frame.width
        let h = frame.height
        
        let cm = checkmarkWidth / 2
        
        // TODO: round out the corners in this.
        
        CGPathMoveToPoint(path, nil, 0, h * (2.0 / 3.0) + cm)
        CGPathAddLineToPoint(path, nil, w / 3.0, h)
        CGPathAddLineToPoint(path, nil, w, cm)
        
        CGPathAddLineToPoint(path, nil, w, -cm)
        CGPathAddLineToPoint(path, nil, w / 3.0, h - cm)
        CGPathAddLineToPoint(path, nil, 0, h * (2.0 / 3.0) - cm)
        CGPathAddLineToPoint(path, nil, 0, h * (2.0 / 3.0) + cm)
        
        return path
    }
    
    func xPath(frame: CGRect, xWidth: CGFloat) -> CGPath {
        let path = CGPathCreateMutable()
        
        let x = frame.origin.x
        let y = frame.origin.y
        let w = frame.width
        let h = frame.height
        
        let xm = xWidth / 2
        
        // TODO: round out the corners in this.
        
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        progressIndicator.setTranslatesAutoresizingMaskIntoConstraints(false)
        self.addSubview(progressIndicator)
        progressIndicator.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
    }
    
    required init(coder: NSCoder) {
        fatalError("")
    }
}

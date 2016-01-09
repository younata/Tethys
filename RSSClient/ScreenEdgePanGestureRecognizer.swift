import UIKit

public class ScreenEdgePanGestureRecognizer: UIPanGestureRecognizer {
    public enum ScreenEdgeStartDirection {
        case Left
        case Right
        case None
    }

    public private(set) var startDirection: ScreenEdgeStartDirection = .None

    private var _delegate: UIGestureRecognizerDelegate? = nil
    public override var delegate: UIGestureRecognizerDelegate? {
        get {
            return self._delegate
        }
        set {
            self._delegate = newValue
        }
    }

    public override init(target: AnyObject?, action: Selector) {
        super.init(target: target, action: action)
        super.delegate = self
    }
}

extension ScreenEdgePanGestureRecognizer: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let view = self.view, let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = gestureRecognizer.velocityInView(view)
            guard fabs(velocity.x) > fabs(velocity.y) else { return false }

            let width = view.bounds.size.width
            let xLocation = gestureRecognizer.locationInView(view).x
            let firstQuarter = xLocation / width < 0.25
            let fourthQuarter = xLocation / width > 0.85
            if firstQuarter {
                self.startDirection = .Left
            } else if fourthQuarter {
                self.startDirection = .Right
            }
            return firstQuarter || fourthQuarter
        }
        return false
    }
}

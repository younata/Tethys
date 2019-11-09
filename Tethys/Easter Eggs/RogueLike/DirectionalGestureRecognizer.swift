import UIKit

final class DirectionalGestureRecognizer: UIGestureRecognizer {
    var direction: CGVector = .zero
    private let deadRadius: CGFloat = 44

    private lazy var deadRadiusSquared: CGFloat = {
        return pow(self.deadRadius, 2)
    }()

    override func reset() {
        self.direction = .zero
        self.startingPosition = nil
        self.state = .possible
    }

    private var startingPosition: CGPoint?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        guard touches.count == 1, let touch = touches.first else { return }

        self.startingPosition = touch.location(in: self.view)
        self.direction = .zero
        self.state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        guard touches.count == 1, let touch = touches.first, let start = self.startingPosition else { return }

        let difference = touch.location(in: self.view) - start

        if difference.magnitudeSquared() < self.deadRadiusSquared {
            // in the deadzone.
            guard self.state != .began else { return }

            self.direction = .zero
        } else {
            self.direction = difference.normalized()
        }
        self.state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)

        self.direction = .zero
        self.startingPosition = nil
        self.state = .ended
    }
}

private extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
        return CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }
}

extension CGVector {
    func magnitudeSquared() -> CGFloat {
        return pow(self.dx, 2) + pow(self.dy, 2)
    }

    func normalized() -> CGVector {
        let x2 = pow(dx, 2)
        let y2 = pow(dy, 2)
        let mag = sqrt(x2 + y2)

        return CGVector(dx: self.dx / mag, dy: self.dy / mag)
    }
}

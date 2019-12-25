import CoreGraphics

extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGVector {
        return CGVector(dx: lhs.x - rhs.x, dy: lhs.y - rhs.y)
    }

    static func + (lhs: CGPoint, rhs: CGVector) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.dx, y: lhs.y + rhs.dy)
    }

    static func += (lhs: inout CGPoint, rhs: CGVector) {
        lhs = lhs + rhs // swiftlint:disable:this shorthand_operator
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

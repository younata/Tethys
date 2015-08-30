import UIKit
import PureLayout_iOS

private class OutlinedLabel: UILabel {
    private var outlineColor = UIColor.darkGreenColor()

    private override func drawTextInRect(rect: CGRect) {
        let textColor = self.textColor
        let context = UIGraphicsGetCurrentContext()
        CGContextSetLineWidth(context, 2);
        CGContextSetLineJoin(context, .Round)

        CGContextSetTextDrawingMode(context, .Stroke)
        self.textColor = self.outlineColor
        super.drawTextInRect(rect)

        CGContextSetTextDrawingMode(context, .Fill);
        self.textColor = textColor
        super.drawTextInRect(rect)
    }
}

public class UnreadCounter: UIView {
    private let triangleLayer = CAShapeLayer()

    private let outlineLabel = OutlinedLabel(forAutoLayout: ())

    public var countLabel: UILabel { return self.outlineLabel }

    public var triangleColor = UIColor.darkGreenColor() {
        didSet {
            self.triangleLayer.fillColor = triangleColor.CGColor
            self.outlineLabel.outlineColor = triangleColor
        }
    }

    public var countColor = UIColor.whiteColor() {
        didSet {
            countLabel.textColor = countColor
        }
    }

    public var hideUnreadText: Bool {
        get {
            return self.countLabel.hidden
        }
        set {
            self.countLabel.hidden = newValue
        }
    }

    public var unread: UInt = 0 {
        didSet {
            unreadDidChange()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let path = CGPathCreateMutable()
        CGPathMoveToPoint(path, nil, 0, 0)
        CGPathAddLineToPoint(path, nil, CGRectGetWidth(self.bounds), 0)
        CGPathAddLineToPoint(path, nil, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds))
        CGPathAddLineToPoint(path, nil, 0, 0)
        triangleLayer.path = path
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.clearColor()

        triangleLayer.strokeColor = UIColor.clearColor().CGColor
        triangleLayer.fillColor = self.triangleColor.CGColor
        self.layer.addSublayer(triangleLayer)

        countLabel.hidden = true
        countLabel.textAlignment = .Right
        countLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        countLabel.textColor = self.countColor

        self.addSubview(countLabel)
        countLabel.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        countLabel.autoPinEdgeToSuperviewEdge(.Trailing, withInset: 4)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("not supported")
    }

    // MARK: - Private

    private func unreadDidChange() {
        if unread == 0 {
            self.hidden = true
        } else {
            countLabel.text = "\(unread)"
            self.hidden = false
        }
    }
}

import UIKit
import PureLayout_iOS

public class UnreadCounter: UIView {

    private lazy var triangleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.clearColor().CGColor
        self.layer.addSublayer(layer)
        return layer
    }()

    public lazy var countLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.hidden = true
        label.textAlignment = .Right
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        label.textColor = self.countColor

        self.addSubview(label)
        label.autoPinEdgeToSuperviewEdge(.Top, withInset: 4)
        label.autoPinEdgeToSuperviewEdge(.Right, withInset: 4)

        return label
    }()

    public var triangleColor = UIColor.darkGreenColor() {
        didSet {
            self.triangleLayer.fillColor = triangleColor.CGColor
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
    }

    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

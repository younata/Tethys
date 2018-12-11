import UIKit
import PureLayout

private class OutlinedLabel: UILabel {
    fileprivate var outlineColor = UIColor.darkGreen

    fileprivate override func drawText(in rect: CGRect) {
        let textColor = self.textColor
        let context = UIGraphicsGetCurrentContext()
        context?.setLineWidth(2)
        context?.setLineJoin(.round)

        context?.setTextDrawingMode(.stroke)
        self.textColor = self.outlineColor
        super.drawText(in: rect)

        context?.setTextDrawingMode(.fill)
        self.textColor = textColor
        super.drawText(in: rect)
    }
}

public final class UnreadCounter: UIView {
    private let numberFormatter = NumberFormatter()
    private let triangleLayer = CAShapeLayer()
    private let outlineLabel = OutlinedLabel(forAutoLayout: ())

    public var countLabel: UILabel { return self.outlineLabel }
    public var triangleColor = UIColor.darkGreen {
        didSet {
            self.triangleLayer.fillColor = self.triangleColor.cgColor
            self.outlineLabel.outlineColor = self.triangleColor
        }
    }

    public var countColor = UIColor.white {
        didSet {
            self.countLabel.textColor = self.countColor
        }
    }

    public var hideUnreadText: Bool {
        get { return self.countLabel.isHidden }
        set { self.countLabel.isHidden = newValue }
    }

    public var unread: Int = 0 {
        didSet {
            assert(unread >= 0)
            self.unreadDidChange()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: self.bounds.width, y: 0))
        path.addLine(to: CGPoint(x: self.bounds.width, y: self.bounds.height))
        path.addLine(to: CGPoint(x: 0, y: 0))
        self.triangleLayer.path = path
    }

    private func unreadDidChange() {
        if self.unread == 0 {
            self.isHidden = true
        } else {
            self.countLabel.text = self.numberFormatter.string(from: NSNumber(value: self.unread))
            self.isHidden = false
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.backgroundColor = UIColor.clear

        self.triangleLayer.strokeColor = UIColor.clear.cgColor
        self.triangleLayer.fillColor = self.triangleColor.cgColor
        self.layer.addSublayer(self.triangleLayer)

        self.countLabel.isHidden = true
        self.countLabel.textAlignment = .right
        self.countLabel.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.body)
        self.countLabel.textColor = self.countColor

        self.addSubview(self.countLabel)
        self.countLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        self.countLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: 4)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("not supported") }
}

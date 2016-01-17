import UIKit
import PureLayout

public class NotificationView: UIView {
    public let titleLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        label.hidden = true
        label.numberOfLines = 0
        return label
    }()

    public let messageLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        label.hidden = true
        label.numberOfLines = 0
        return label
    }()

    public func display(title: String, message: String, animated: Bool = true) {
        self.titleLabel.text = title
        self.titleLabel.hidden = false
        self.messageLabel.text = message
        self.messageLabel.hidden = false

        let height = self.requiredHeight(title, message: message)
        self.heightConstraint?.constant = height
        let bounds = CGRectMake(0, 0, self.bounds.width, height)
        self.recomputeMask(bounds)

        self.changeLayout(animated, spring: true, delay: 0) {_ in
            self.hide()
        }
    }

    public func hide(animated: Bool = true, delay: NSTimeInterval = 2.0) {
        self.heightConstraint?.constant = 0
        self.changeLayout(animated, spring: false, delay: delay) {_ in
            self.titleLabel.text = nil
            self.titleLabel.hidden = true
            self.messageLabel.text = nil
            self.messageLabel.hidden = true
        }
    }

    private var heightConstraint: NSLayoutConstraint?

    private let maskLayer = CAShapeLayer()

    public override func didMoveToSuperview() {
        super.didMoveToSuperview()

        self.clipsToBounds = true
        self.layer.mask = self.maskLayer

        self.titleLabel.removeFromSuperview()
        self.messageLabel.removeFromSuperview()
        self.addSubview(self.titleLabel)
        self.addSubview(self.messageLabel)

        self.titleLabel.autoPinEdgesToSuperviewMarginsExcludingEdge(.Bottom)
        self.messageLabel.autoPinEdgesToSuperviewMarginsExcludingEdge(.Top)
        self.messageLabel.autoPinEdge(.Top,
            toEdge: .Bottom,
            ofView: self.titleLabel,
            withOffset: 4,
            relation: .LessThanOrEqual)

        self.translatesAutoresizingMaskIntoConstraints = false
        self.heightConstraint = self.autoSetDimension(.Height, toSize: 0)
    }

    private func requiredHeight(title: String, message: String) -> CGFloat {
        let titleFont = self.titleLabel.font
        let messageFont = self.messageLabel.font

        let marginHeight = self.layoutMargins.top + self.layoutMargins.bottom + 4

        let sizeOptions: NSStringDrawingOptions = [.UsesDeviceMetrics, .UsesFontLeading, .UsesLineFragmentOrigin]

        let width = self.bounds.width - (self.layoutMargins.left + self.layoutMargins.right)
        let size = CGSizeMake(width, CGFloat.infinity)

        let titleHeight = NSString(string: title).boundingRectWithSize(size,
            options: sizeOptions,
            attributes: [NSFontAttributeName: titleFont],
            context: nil).size.height

        let messageHeight = NSString(string: message).boundingRectWithSize(size,
            options: sizeOptions,
            attributes: [NSFontAttributeName: messageFont],
            context: nil).size.height

        return marginHeight + titleHeight + messageHeight
    }

    private func recomputeMask(bounds: CGRect) {
        let bezierPath = UIBezierPath(roundedRect: bounds,
            byRoundingCorners: [.BottomLeft, .BottomRight],
            cornerRadii: CGSize(width: 10, height: 10))
        self.maskLayer.frame = bounds
        self.maskLayer.path = bezierPath.CGPath
    }

    private func changeLayout(animated: Bool, spring: Bool, delay: NSTimeInterval, completion: Bool -> Void) {
        let duration: NSTimeInterval = animated ? 0.75 : 0
        UIView.animateWithDuration(duration,
            delay: delay,
            usingSpringWithDamping: spring ? 0.5 : 1.0,
            initialSpringVelocity: 0,
            options: [],
            animations: {
                self.layoutIfNeeded()
            }, completion: completion)
    }
}

extension NotificationView: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(themeRepository: ThemeRepository) {
        self.titleLabel.textColor = themeRepository.backgroundColor
        self.messageLabel.textColor = themeRepository.backgroundColor
        self.backgroundColor = themeRepository.errorColor
    }
}

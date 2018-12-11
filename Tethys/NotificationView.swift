import UIKit
import PureLayout

public final class NotificationView: UIView {
    public let titleLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        label.isHidden = true
        label.numberOfLines = 0
        return label
    }()

    public let messageLabel: UILabel = {
        let label = UILabel(forAutoLayout: ())
        label.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
        label.isHidden = true
        label.numberOfLines = 0
        return label
    }()

    public func display(_ title: String, message: String, animated: Bool = true) {
        self.titleLabel.text = title
        self.titleLabel.isHidden = false
        self.messageLabel.text = message
        self.messageLabel.isHidden = false

        let height = self.requiredHeight(title, message: message)
        self.heightConstraint?.constant = height
        let bounds = CGRect(x: 0, y: 0, width: self.bounds.width, height: height)
        self.recomputeMask(bounds)

        self.changeLayout(animated, spring: true, delay: 0) {_ in
            self.hide()
        }
    }

    public func hide(_ animated: Bool = true, delay: TimeInterval = 2.0) {
        self.heightConstraint?.constant = 0
        self.changeLayout(animated, spring: false, delay: delay) {_ in
            self.titleLabel.text = nil
            self.titleLabel.isHidden = true
            self.messageLabel.text = nil
            self.messageLabel.isHidden = true
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

        self.titleLabel.autoPinEdges(toSuperviewMarginsExcludingEdge: .bottom)
        self.messageLabel.autoPinEdges(toSuperviewMarginsExcludingEdge: .top)
        self.messageLabel.autoPinEdge(.top,
            to: .bottom,
            of: self.titleLabel,
            withOffset: 4,
            relation: .lessThanOrEqual)

        self.translatesAutoresizingMaskIntoConstraints = false
        self.heightConstraint = self.autoSetDimension(.height, toSize: 0)
    }

    private func requiredHeight(_ title: String, message: String) -> CGFloat {
        let titleFont = self.titleLabel.font!
        let messageFont = self.messageLabel.font!

        let marginHeight = self.layoutMargins.top + self.layoutMargins.bottom + 4

        let sizeOptions: NSStringDrawingOptions = [.usesDeviceMetrics, .usesFontLeading, .usesLineFragmentOrigin]

        let width = self.bounds.width - (self.layoutMargins.left + self.layoutMargins.right)
        let size = CGSize(width: width, height: CGFloat.infinity)

        let titleHeight = title.boundingRect(with: size,
            options: sizeOptions,
            attributes: [NSAttributedString.Key.font: titleFont],
            context: nil).size.height

        let messageHeight = message.boundingRect(with: size,
            options: sizeOptions,
            attributes: [NSAttributedString.Key.font: messageFont],
            context: nil).size.height

        return marginHeight + titleHeight + messageHeight
    }

    private func recomputeMask(_ bounds: CGRect) {
        let bezierPath = UIBezierPath(roundedRect: bounds,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: 10, height: 10))
        self.maskLayer.frame = bounds
        self.maskLayer.path = bezierPath.cgPath
    }

    private func changeLayout(_ animated: Bool,
                              spring: Bool,
                              delay: TimeInterval,
                              completion: @escaping (Bool) -> Void) {
        let duration: TimeInterval = animated ? 0.75 : 0
        UIView.animate(withDuration: duration,
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
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.titleLabel.textColor = themeRepository.backgroundColor
        self.messageLabel.textColor = themeRepository.backgroundColor
        self.backgroundColor = themeRepository.errorColor
    }
}

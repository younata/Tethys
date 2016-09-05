import UIKit

public final class SwitchTableViewCell: UITableViewCell {
    private var _textLabel = UILabel(forAutoLayout: ())
    public override var textLabel: UILabel? { return self._textLabel }

    public override var detailTextLabel: UILabel? { return nil }

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public let theSwitch: UISwitch = UISwitch(forAutoLayout: ())
    public var onTapSwitch: ((UISwitch) -> (Void))? = nil

    @objc private func didTapSwitch() {
        self.onTapSwitch?(self.theSwitch)
    }

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.addSubview(self._textLabel)
        self._textLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 4, left: 20, bottom: 4, right: 0),
            excludingEdge: .trailing)
        self.contentView.addSubview(self.theSwitch)
        self.theSwitch.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 5, left: 0, bottom: 4, right: 20),
            excludingEdge: .leading)
        self.theSwitch.autoPinEdge(.leading, to: .trailing, of: self._textLabel)

        self.theSwitch.addTarget(self, action: #selector(SwitchTableViewCell.didTapSwitch),
                                 for: .valueChanged)
    }

    public required init?(coder aDecoder: NSCoder) { fatalError() }
}

extension SwitchTableViewCell: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.backgroundColor = self.themeRepository?.backgroundColor
        self.textLabel?.textColor = self.themeRepository?.textColor
    }
}

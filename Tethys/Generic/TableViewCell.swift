import UIKit

public final class TableViewCell: UITableViewCell, ThemeRepositorySubscriber {
    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        self.textLabel?.text = nil
        self.detailTextLabel?.text = nil
    }

    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.textLabel?.textColor = self.themeRepository?.textColor
        self.detailTextLabel?.textColor = self.themeRepository?.textColor

        self.updateBackgroundColor(self.isSelected)
    }

    public override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        self.updateBackgroundColor(selected)
    }

    private func updateBackgroundColor(_ selected: Bool) {
        self.backgroundColor = selected ? self.themeRepository?.highlightColor : self.themeRepository?.backgroundColor
    }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
    }

    public required init(coder aDecoder: NSCoder) { fatalError("not supported") }
}

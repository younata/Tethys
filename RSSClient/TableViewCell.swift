import UIKit

public class TableViewCell: UITableViewCell, ThemeRepositorySubscriber {
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

    public func didChangeTheme() {
        self.textLabel?.textColor = self.themeRepository?.textColor
        self.detailTextLabel?.textColor = self.themeRepository?.textColor

        self.updateBackgroundColor(self.selected)
    }

    public override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        self.updateBackgroundColor(selected)
    }

    private func updateBackgroundColor(selected: Bool) {
        self.backgroundColor = selected ? UIColor.darkGreenColor() : self.themeRepository?.backgroundColor
    }

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .Value1, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .None
    }

    public required init(coder aDecoder: NSCoder) { fatalError("not supported") }
}

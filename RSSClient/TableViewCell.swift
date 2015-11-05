import UIKit

public class TableViewCell: UITableViewCell, ThemeRepositorySubscriber {
    public required init(coder aDecoder: NSCoder) {
        fatalError("not supported")
    }

    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .Value1, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .None
    }

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public func didChangeTheme() {
        self.textLabel?.textColor = self.themeRepository?.textColor
        self.detailTextLabel?.textColor = self.themeRepository?.textColor

        self.backgroundColor = self.themeRepository?.backgroundColor
    }
}
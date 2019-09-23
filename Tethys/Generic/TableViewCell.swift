import UIKit

public final class TableViewCell: UITableViewCell {
    public override func prepareForReuse() {
        super.prepareForReuse()
        self.textLabel?.text = nil
        self.detailTextLabel?.text = nil

        self.textLabel?.textColor = Theme.textColor
        self.detailTextLabel?.textColor = Theme.textColor

        self.accessibilityLabel = nil
    }

    public override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        self.backgroundColor = selected ? Theme.highlightColor : Theme.backgroundColor
    }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none

        self.isAccessibilityElement = true
    }

    public required init(coder aDecoder: NSCoder) { fatalError("not supported") }
}

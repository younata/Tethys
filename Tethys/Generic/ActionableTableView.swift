import UIKit

public final class ActionableTableView: UIView {
    public let tableView = UITableView(forAutoLayout: ())

    private let actionsStackView = UIStackView(forAutoLayout: ())

    private var tableHeight: NSLayoutConstraint?
    public var maxHeight: CGFloat = 300 {
        didSet { self.recalculateHeightConstraint() }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.actionsStackView)
        self.addSubview(self.tableView)

        self.actionsStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40),
                                                           excludingEdge: .bottom)
        self.tableView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.tableView.autoPinEdge(.top, to: .bottom, of: self.actionsStackView)
        self.tableHeight = self.tableView.autoSetDimension(.height, toSize: 0)

        self.tableView.tableFooterView = UIView()
        self.tableView.rowHeight = UITableView.automaticDimension

        self.actionsStackView.axis = .horizontal
        self.actionsStackView.distribution = .equalSpacing
        self.actionsStackView.alignment = .center

        self.tableView.backgroundColor = Theme.backgroundColor
        self.tableView.separatorColor = Theme.separatorColor
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // be sure to call this whenever the backing model changes size
    public func recalculateHeightConstraint() {
        guard let constraint = self.tableHeight else { return }

        let estimatedHeight = self.tableView.estimatedTableHeight()
        let proposedHeight: CGFloat = min(self.maxHeight, estimatedHeight)
        constraint.constant = max(0, proposedHeight)
    }

    public func setActions(_ actions: [UIView]) {
        self.actionsStackView.arrangedSubviews.forEach(self.actionsStackView.removeArrangedSubview)

        actions.forEach(self.actionsStackView.addArrangedSubview)
    }

    public func reloadData() {
        self.tableView.reloadData()
        self.recalculateHeightConstraint()
    }
}

private extension UITableView {
    func totalNumberOfRows() -> Int {
        var rowCount: Int = 0
        let sectionCount: Int = self.numberOfSections
        for section in 0..<sectionCount {
            rowCount += self.numberOfRows(inSection: section)
        }
        return rowCount
    }

    func estimatedTableHeight() -> CGFloat {
        return CGFloat(self.totalNumberOfRows()) * self.estimatedRowHeight
    }
}

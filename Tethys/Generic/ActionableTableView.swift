import UIKit

public final class ActionableTableView: UIView {
    public let tableView = UITableView(forAutoLayout: ())

    private let actionsStackView = UIStackView(forAutoLayout: ())

    private var tableHeight: NSLayoutConstraint?
    public var maxHeight: Int = 300 {
        didSet { self.recalculateHeightConstraint() }
    }

    public var themeRepository: ThemeRepository? {
        didSet {
            themeRepository?.addSubscriber(self)
        }
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
        self.tableView.rowHeight = UITableViewAutomaticDimension

        self.actionsStackView.axis = .horizontal
        self.actionsStackView.distribution = .equalSpacing
        self.actionsStackView.alignment = .center
    }

    public required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // be sure to call this whenever the backing model changes size
    public func recalculateHeightConstraint() {
        let tableSize: Int = (0..<self.tableView.numberOfSections).reduce(0) { total, section in
            return total + self.tableView.numberOfRows(inSection: section)
        }
        let absoluteMaxHeight = tableSize * Int(self.tableView.estimatedRowHeight)
        self.tableHeight!.constant = CGFloat(max(0, min(self.maxHeight, absoluteMaxHeight)))
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

extension ActionableTableView: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableView.separatorColor = themeRepository.textColor

        self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle
    }
}

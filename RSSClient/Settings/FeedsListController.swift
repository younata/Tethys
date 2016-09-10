import UIKit
import rNewsKit
import PureLayout

public final class FeedsListController: UIViewController {
    public var feeds = [Feed]() {
        didSet {
            self.tableView.reloadData()
        }
    }

    public var themeRepository: ThemeRepository? = nil {
        didSet {
            self.themeRepository?.addSubscriber(self)
        }
    }

    public var tapFeed: ((Feed, Int) -> Void)? = nil
    public var editActionsForFeed: ((Feed) -> [UITableViewRowAction]?)? = nil

    public let tableView = UITableView()

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.register(FeedTableCell.self, forCellReuseIdentifier: "unread")
        self.tableView.register(FeedTableCell.self, forCellReuseIdentifier: "read")
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges()
    }
}

extension FeedsListController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = self.themeRepository?.backgroundColor
        self.tableView.separatorColor = self.themeRepository?.textColor
        if let themeRepo = self.themeRepository {
            self.tableView.indicatorStyle = themeRepo.scrollIndicatorStyle
        }
    }
}

extension FeedsListController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.feeds.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let feed = self.feeds[indexPath.row]
        let identifier = feed.unreadArticles.isEmpty ? "unread" : "read"

        guard let cell = tableView.dequeueReusableCell(withIdentifier: identifier,
                                                       for: indexPath) as? FeedTableCell else {
                return UITableViewCell()
        }
        cell.feed = feed
        cell.themeRepository = self.themeRepository
        return cell
    }
}

extension FeedsListController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        self.tapFeed?(self.feeds[indexPath.row], indexPath.row)
    }

    public func tableView(_ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
            return self.editActionsForFeed?(self.feeds[indexPath.row])
    }

    public func tableView(_ tableView: UITableView,
        commit editingStyle: UITableViewCellEditingStyle,
        forRowAt indexPath: IndexPath) {}
}

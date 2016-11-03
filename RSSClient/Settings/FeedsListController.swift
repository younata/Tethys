import UIKit
import rNewsKit
import PureLayout
import CBGPromise

public final class FeedsListController: UIViewController {
    public var feeds = [Feed]() {
        didSet {
            self.tableView.reloadData()
        }
    }

    fileprivate let themeRepository: ThemeRepository
    fileprivate let mainQueue: OperationQueue

    public var tapFeed: ((Feed) -> Void)? = nil

    public private(set) lazy var tableView: UITableView = {
        let tableView = UITableView(forAutoLayout: ())
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        return tableView
    }()

    fileprivate lazy var feedsDeleSource: FeedsDeleSource = {
        return FeedsDeleSource(
            tableView: self.tableView,
            feedsSource: self,
            themeRepository: self.themeRepository,
            navigationController: nil,
            mainQueue: self.mainQueue,
            articleListController: nil
        )
    }()

    public init(mainQueue: OperationQueue,
                themeRepository: ThemeRepository) {
        self.mainQueue = mainQueue
        self.themeRepository = themeRepository

        super.init(nibName: nil, bundle: nil)

        themeRepository.addSubscriber(self)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.dataSource = self.feedsDeleSource
        self.tableView.delegate = self.feedsDeleSource
        self.view.addSubview(self.tableView)
        self.tableView.autoPinEdgesToSuperviewEdges()
    }

    var _previewActionItems: [UIPreviewAction] = []
    public override var previewActionItems: [UIPreviewActionItem] {
        return self._previewActionItems
    }
}

extension FeedsListController: FeedsSource {
    public func editFeed(feed: Feed) {}
    public func shareFeed(feed: Feed) {}
    public func markRead(feed: Feed) -> Future<Void> {
        let promise = Promise<Void>()
        promise.resolve()
        return promise.future
    }

    public func deleteFeed(feed: Feed) -> Future<Bool> {
        let promise = Promise<Bool>()
        promise.resolve(false)
        return promise.future
    }

    public func selectFeed(feed: Feed) {
        self.tapFeed?(feed)
    }
}

extension FeedsListController: ThemeRepositorySubscriber {
    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.tableView.backgroundColor = themeRepository.backgroundColor
        self.tableView.separatorColor = themeRepository.textColor
        self.tableView.indicatorStyle = themeRepository.scrollIndicatorStyle
    }
}

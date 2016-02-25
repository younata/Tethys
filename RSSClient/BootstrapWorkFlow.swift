import WorkFlow
import rNewsKit
import Ra

public class BootstrapWorkFlow {
    private var workflow: LinearWorkFlow!

    private let window: UIWindow
    private let feedRepository: FeedRepository
    private let migrationUseCase: MigrationUseCase
    private let splitViewController: SplitViewController
    private let feedsTableViewController: Void -> FeedsTableViewController
    private let articleViewController: Void -> ArticleViewController

    private let initialLaunch = false

    // swiftlint:disable function_parameter_count
    public init(window: UIWindow,
        feedRepository: FeedRepository,
        migrationUseCase: MigrationUseCase,
        splitViewController: SplitViewController,
        feedsTableViewController: Void -> FeedsTableViewController,
        articleViewController: Void -> ArticleViewController) {
        self.window = window
        self.feedRepository = feedRepository
        self.migrationUseCase = migrationUseCase
        self.splitViewController = splitViewController
        self.feedsTableViewController = feedsTableViewController
        self.articleViewController = articleViewController
    }
    // swiftlint:enable function_parameter_count

    public convenience init(window: UIWindow, injector: Injector) {
        self.init(
            window: window,
            feedRepository: injector.create(FeedRepository)!,
            migrationUseCase: injector.create(MigrationUseCase)!,
            splitViewController: injector.create(SplitViewController)!,
            feedsTableViewController: { injector.create(FeedsTableViewController)! },
            articleViewController: { injector.create(ArticleViewController)! }
        )
    }

    private var feedAndArticle: (feed: Feed, article: Article)?
    public func begin(feedAndArticle: (feed: Feed, article: Article)? = nil) {
        self.feedAndArticle = feedAndArticle
        if self.initialLaunch {

        } else {
            if self.feedRepository.databaseUpdateAvailable() {
                self.workflow = LinearWorkFlow(
                    components: [self.migrationUseCase],
                    advance: self.workFlowDidAdvance,
                    finish: self.workFlowDidFinish,
                    cancel: self.workFlowDidFinish
                )
                self.workflow.startWorkFlow()
            } else {
                self.showFeedsController()
            }
        }
    }

    public func workFlowDidAdvance(workFlow: WorkFlow) {
    }

    public func workFlowDidFinish(workFlow: WorkFlow) {
        self.showFeedsController()
    }

    private func showFeedsController() {
        let feedsTableViewController = self.feedsTableViewController()
        self.splitViewController.masterNavigationController.viewControllers = [
            feedsTableViewController
        ]
        self.splitViewController.detailNavigationController.viewControllers = [
            self.articleViewController()
        ]
        self.splitViewController.viewControllers = [
            self.splitViewController.masterNavigationController,
            self.splitViewController.detailNavigationController
        ]

        if let (feed, article) = self.feedAndArticle {
            let articleListController = feedsTableViewController.showFeeds([feed], animated: false)
            articleListController.showArticle(article, animated: false)
        }

        self.window.rootViewController = self.splitViewController
    }
}

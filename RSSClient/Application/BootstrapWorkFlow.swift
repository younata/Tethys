import WorkFlow
import rNewsKit
import Ra

public protocol Bootstrapper {
    func begin(feedAndArticle: (feed: Feed, article: Article)?)
}

public class BootstrapWorkFlow: Bootstrapper {
    private var workflow: LinearWorkFlow!

    private let window: UIWindow
    private let feedRepository: DatabaseUseCase
    private let migrationUseCase: MigrationUseCase
    private let splitViewController: SplitViewController
    private let migrationViewController: Void -> MigrationViewController
    private let feedsTableViewController: Void -> FeedsTableViewController
    private let articleViewController: Void -> ArticleViewController

    private let initialLaunch = false

    // swiftlint:disable function_parameter_count
    public init(window: UIWindow,
        feedRepository: DatabaseUseCase,
        migrationUseCase: MigrationUseCase,
        splitViewController: SplitViewController,
        migrationViewController: Void -> MigrationViewController,
        feedsTableViewController: Void -> FeedsTableViewController,
        articleViewController: Void -> ArticleViewController) {
        self.window = window
        self.feedRepository = feedRepository
        self.migrationUseCase = migrationUseCase
        self.splitViewController = splitViewController
        self.migrationViewController = migrationViewController
        self.feedsTableViewController = feedsTableViewController
        self.articleViewController = articleViewController
    }
    // swiftlint:enable function_parameter_count

    public convenience init(window: UIWindow, injector: Injector) {
        self.init(
            window: window,
            feedRepository: injector.create(DatabaseUseCase)!,
            migrationUseCase: injector.create(MigrationUseCase)!,
            splitViewController: injector.create(SplitViewController)!,
            migrationViewController: { injector.create(MigrationViewController)! },
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
                self.showMigrationViewController()
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

    private func showMigrationViewController() {
        self.window.rootViewController = self.migrationViewController()
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
            let articleListController = feedsTableViewController.showFeed(feed, animated: false)
            articleListController.showArticle(article, animated: false)
        }

        self.window.rootViewController = self.splitViewController
    }
}

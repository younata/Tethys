import WorkFlow
import TethysKit

public protocol Bootstrapper {
    func begin(_ feedAndArticle: (feed: Feed, article: Article)?)
}

public final class BootstrapWorkFlow: Bootstrapper {
    private var workflow: LinearWorkFlow!

    private let window: UIWindow
    private let feedRepository: DatabaseUseCase
    private let migrationUseCase: MigrationUseCase
    private let splitViewController: SplitViewController
    private let migrationViewController: () -> MigrationViewController
    private let feedsTableViewController: () -> FeedsTableViewController
    private let articleViewController: () -> ArticleViewController

    private let initialLaunch = false

    // swiftlint:disable function_parameter_count
    public init(window: UIWindow,
                feedRepository: DatabaseUseCase,
                migrationUseCase: MigrationUseCase,
                splitViewController: SplitViewController,
                migrationViewController: @escaping () -> MigrationViewController,
                feedsTableViewController: @escaping () -> FeedsTableViewController,
                articleViewController: @escaping () -> ArticleViewController) {
        self.window = window
        self.feedRepository = feedRepository
        self.migrationUseCase = migrationUseCase
        self.splitViewController = splitViewController
        self.migrationViewController = migrationViewController
        self.feedsTableViewController = feedsTableViewController
        self.articleViewController = articleViewController
    }
    // swiftlint:enable function_parameter_count

    private var feedAndArticle: (feed: Feed, article: Article)?
    public func begin(_ feedAndArticle: (feed: Feed, article: Article)? = nil) {
        self.feedAndArticle = feedAndArticle
        if !self.initialLaunch {
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

    public func workFlowDidAdvance(_ workFlow: WorkFlow) {
    }

    public func workFlowDidFinish(_ workFlow: WorkFlow) {
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
            _ = articleListController.showArticle(article, animated: false)
        }

        self.window.rootViewController = self.splitViewController
    }
}

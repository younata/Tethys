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

    private let initialLaunch = false

    public init(window: UIWindow,
        feedRepository: FeedRepository,
        migrationUseCase: MigrationUseCase,
        splitViewController: SplitViewController,
        feedsTableViewController: Void -> FeedsTableViewController) {
        self.window = window
        self.feedRepository = feedRepository
        self.migrationUseCase = migrationUseCase
        self.splitViewController = splitViewController
        self.feedsTableViewController = feedsTableViewController
    }

    public convenience init(window: UIWindow, injector: Injector) {
        self.init(
            window: window,
            feedRepository: injector.create(FeedRepository)!,
            migrationUseCase: injector.create(MigrationUseCase)!,
            splitViewController: injector.create(SplitViewController)!,
            feedsTableViewController: { injector.create(FeedsTableViewController)! }
        )
    }

    public func begin() {
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
        self.splitViewController.masterNavigationController.viewControllers = [
            self.feedsTableViewController()
        ]
        self.splitViewController.viewControllers = [
            self.splitViewController.masterNavigationController,
            self.splitViewController.detailNavigationController
        ]
        self.window.rootViewController = self.splitViewController
    }
}

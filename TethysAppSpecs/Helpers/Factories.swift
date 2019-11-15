@testable import Tethys
import TethysKit
import AuthenticationServices

func splitViewControllerFactory() -> SplitViewController {
    return SplitViewController()
}

func findFeedViewControllerFactory(
    importUseCase: ImportUseCase = FakeImportUseCase(),
    analytics: Analytics = FakeAnalytics(),
    notificationCenter: NotificationCenter = NotificationCenter()
    ) -> FindFeedViewController {
    return FindFeedViewController(
        importUseCase: importUseCase,
        analytics: analytics,
        notificationCenter: notificationCenter
    )
}

func feedViewControllerFactory(
    feed: Feed = feedFactory(),
    feedService: FeedService = FakeFeedService(),
    tagEditorViewController: @escaping () -> TagEditorViewController = { tagEditorViewControllerFactory() }
    ) -> FeedViewController {
    return FeedViewController(
        feed: feed,
        feedService: feedService,
        tagEditorViewController: tagEditorViewController
    )
}

func tagEditorViewControllerFactory(
    feedService: FeedService = FakeFeedService()
    ) -> TagEditorViewController {
    return TagEditorViewController(
        feedService: feedService
    )
}

func feedListControllerFactory(
    feedCoordinator: FeedCoordinator = FakeFeedCoordinator(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    messenger: Messenger = FakeMessenger(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    notificationCenter: NotificationCenter = NotificationCenter(),
    findFeedViewController: @escaping () -> FindFeedViewController = { findFeedViewControllerFactory() },
    feedViewController: @escaping (Feed) -> FeedViewController = { feed in feedViewControllerFactory(feed: feed) },
    settingsViewController: @escaping () -> SettingsViewController = { settingsViewControllerFactory() },
    articleListController: @escaping (Feed) -> ArticleListController = { feed in articleListControllerFactory(feed: feed) }
    ) -> FeedListController {
    return FeedListController(
        feedCoordinator: feedCoordinator,
        settingsRepository: SettingsRepository(userDefaults: nil),
        messenger: messenger,
        mainQueue: mainQueue,
        notificationCenter: notificationCenter,
        findFeedViewController: findFeedViewController,
        feedViewController: feedViewController,
        settingsViewController: settingsViewController,
        articleListController: articleListController
    )
}

func articleViewControllerFactory(
    article: Article = articleFactory(),
    articleUseCase: ArticleUseCase = FakeArticleUseCase(),
    htmlViewController: @escaping () -> HTMLViewController = { htmlViewControllerFactory() }
    ) -> ArticleViewController {
    return ArticleViewController(
        article: article,
        articleUseCase: articleUseCase,
        htmlViewController: htmlViewController
    )
}

func htmlViewControllerFactory() -> HTMLViewController {
    return HTMLViewController()
}

func articleListControllerFactory(
    feed: Feed = feedFactory(),
    mainQueue: OperationQueue = FakeOperationQueue(),
    messenger: Messenger = FakeMessenger(),
    feedCoordinator: FeedCoordinator = FakeFeedCoordinator(),
    articleCoordinator: ArticleCoordinator = FakeArticleCoordinator(),
    notificationCenter: NotificationCenter = NotificationCenter(),
    articleCellController: ArticleCellController = FakeArticleCellController(),
    articleViewController: @escaping (Article) -> ArticleViewController = { article in articleViewControllerFactory(article: article) }
    ) -> ArticleListController {
    return ArticleListController(
        feed: feed,
        mainQueue: mainQueue,
        messenger: messenger,
        feedCoordinator: feedCoordinator,
        articleCoordinator: articleCoordinator,
        notificationCenter: notificationCenter,
        articleCellController: articleCellController,
        articleViewController: articleViewController
    )
}

func breakout3DEasterEggViewControllerFactory(
    mainQueue: FakeOperationQueue = FakeOperationQueue()
    ) -> Breakout3DEasterEggViewController {
    return Breakout3DEasterEggViewController(
        mainQueue: mainQueue
    )
}

func settingsViewControllerFactory(
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    opmlService: OPMLService = FakeOPMLService(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    accountService: AccountService = FakeAccountService(),
    messenger: Messenger = FakeMessenger(),
    appIconChanger: AppIconChanger = FakeAppIconChanger(),
    loginController: LoginController = FakeLoginController(),
    documentationViewController: @escaping (Documentation) -> DocumentationViewController = { docs in documentationViewControllerFactory(documentation: docs) },
    appIconChangeController: @escaping () -> UIViewController = { UIViewController() },
    easterEggViewController: @escaping () -> UIViewController = { UIViewController() }
    ) -> SettingsViewController {
    return SettingsViewController(
        settingsRepository: settingsRepository,
        opmlService: opmlService,
        mainQueue: mainQueue,
        accountService: accountService,
        messenger: messenger,
        appIconChanger: appIconChanger,
        loginController: loginController,
        documentationViewController: documentationViewController,
        appIconChangeController: appIconChangeController,
        easterEggViewController: easterEggViewController
    )
}

func documentationViewControllerFactory(
    documentation: Documentation = .libraries,
    htmlViewController: HTMLViewController = htmlViewControllerFactory()
    ) -> DocumentationViewController {
    return DocumentationViewController(
        documentation: documentation,
        htmlViewController: htmlViewController
    )
}

func augmentedRealityViewControllerFactory(
    mainQueue: OperationQueue = FakeOperationQueue(),
    feedListController: @escaping () -> FeedListController = { return feedListControllerFactory() }
) -> AugmentedRealityEasterEggViewController {
    return AugmentedRealityEasterEggViewController(
        mainQueue: mainQueue,
        feedListControllerFactory: feedListController
    )
}

// Repositories

func settingsRepositoryFactory(userDefaults: UserDefaults? = nil) -> SettingsRepository {
    return SettingsRepository(userDefaults: userDefaults)
}

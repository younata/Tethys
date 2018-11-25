import Tethys
import TethysKit

//func SettingsViewControllerFactory() -> SettingsViewController {
//
//}

// View Controllers

func splitViewControllerFactory(themeRepository: ThemeRepository = themeRepositoryFactory()) -> SplitViewController {
    return SplitViewController(themeRepository: themeRepository)
}

func findFeedViewControllerFactory(
    importUseCase: ImportUseCase = FakeImportUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    analytics: Analytics = FakeAnalytics()
    ) -> FindFeedViewController {
    return FindFeedViewController(importUseCase: importUseCase, themeRepository: themeRepository, analytics: analytics)
}

func feedViewControllerFactory(
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    tagEditorViewController: @escaping () -> TagEditorViewController = { tagEditorViewControllerFactory() }
    ) -> FeedViewController {
    return FeedViewController(
        feedRepository: feedRepository,
        themeRepository: themeRepository,
        tagEditorViewController: tagEditorViewController
    )
}

func tagEditorViewControllerFactory(
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory()
    ) -> TagEditorViewController {
    return TagEditorViewController(
        feedRepository: feedRepository,
        themeRepository: themeRepository
    )
}

func feedsTableViewControllerFactory(
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    findFeedViewController: @escaping () -> FindFeedViewController = { findFeedViewControllerFactory() },
    feedViewController: @escaping () -> FeedViewController = { feedViewControllerFactory() },
    settingsViewController: @escaping () -> SettingsViewController = { settingsViewControllerFactory() },
    articleListController: @escaping (Feed) -> ArticleListController = { feed in articleListControllerFactory(feed: feed) }
    ) -> FeedsTableViewController {
    return FeedsTableViewController(
        feedRepository: feedRepository,
        themeRepository: themeRepository,
        settingsRepository: SettingsRepository(userDefaults: nil),
        mainQueue: FakeOperationQueue(),
        findFeedViewController: findFeedViewController,
        feedViewController: feedViewController,
        settingsViewController: settingsViewController,
        articleListController: articleListController
    )
}

func articleViewControllerFactory(
    article: Article = articleFactory(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    articleUseCase: ArticleUseCase = FakeArticleUseCase(),
    htmlViewController: @escaping () -> HTMLViewController = { htmlViewControllerFactory() }
    ) -> ArticleViewController {
    return ArticleViewController(
        article: article,
        themeRepository: themeRepository,
        articleUseCase: articleUseCase,
        htmlViewController: htmlViewController
    )
}

func htmlViewControllerFactory(themeRepository: ThemeRepository = themeRepositoryFactory()) -> HTMLViewController {
    return HTMLViewController(
        themeRepository: themeRepository
    )
}

func articleListControllerFactory(
    feed: Feed = feedFactory(),
    feedService: FeedService = FakeFeedService(),
    articleService: ArticleService = FakeArticleService(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    articleCellController: ArticleCellController = FakeArticleCellController(),
    articleViewController: @escaping (Article) -> ArticleViewController = { article in articleViewControllerFactory(article: article) }
    ) -> ArticleListController {
    return ArticleListController(
        feed: feed,
        feedService: feedService,
        articleService: articleService,
        themeRepository: themeRepository,
        articleCellController: articleCellController,
        articleViewController: articleViewController
    )
}

func migrationViewControllerFactory(
    migrationUseCase: MigrationUseCase = FakeMigrationUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    mainQueue: FakeOperationQueue = FakeOperationQueue()
    ) -> MigrationViewController {
    return MigrationViewController(
        migrationUseCase: migrationUseCase,
        themeRepository: themeRepository,
        mainQueue: mainQueue
    )
}

func settingsViewControllerFactory(
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    quickActionRepository: QuickActionRepository = FakeQuickActionRepository(),
    databaseUseCase: DatabaseUseCase = FakeDatabaseUseCase(),
    opmlService: OPMLService = FakeOPMLService(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    documentationViewController: @escaping () -> DocumentationViewController = { documentationViewControllerFactory() }
    ) -> SettingsViewController {
    return SettingsViewController(
        themeRepository: themeRepository,
        settingsRepository: settingsRepository,
        quickActionRepository: quickActionRepository,
        databaseUseCase: databaseUseCase,
        opmlService: opmlService,
        mainQueue: mainQueue,
        documentationViewController: documentationViewController
    )
}

func documentationViewControllerFactory(
    documentationUseCase: DocumentationUseCase = FakeDocumentationUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    htmlViewController: HTMLViewController = htmlViewControllerFactory()
    ) -> DocumentationViewController {
    return DocumentationViewController(
        documentationUseCase: documentationUseCase,
        themeRepository: themeRepository,
        htmlViewController: htmlViewController
    )
}

func blankViewControllerFactory(
    themeRepository: ThemeRepository = themeRepositoryFactory()
    ) -> BlankViewController {
    return BlankViewController(
        themeRepository: themeRepository
    )
}

// Workflows

func bootstrapWorkFlowFactory(
    window: UIWindow = UIWindow(),
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    migrationUseCase: MigrationUseCase = FakeMigrationUseCase(),
    splitViewController: SplitViewController = splitViewControllerFactory(),
    migrationViewController: @escaping () -> MigrationViewController = { migrationViewControllerFactory() },
    feedsTableViewController: @escaping () -> FeedsTableViewController = { feedsTableViewControllerFactory() },
    blankViewController: @escaping () -> BlankViewController = { blankViewControllerFactory() }
    ) -> BootstrapWorkFlow {
    return BootstrapWorkFlow(
        window: window,
        feedRepository: feedRepository,
        migrationUseCase: migrationUseCase,
        splitViewController: splitViewController,
        migrationViewController: migrationViewController,
        feedsTableViewController: feedsTableViewController,
        blankViewController: blankViewController
    )
}

// Repositories

func themeRepositoryFactory(userDefaults: UserDefaults? = nil) -> ThemeRepository {
    return ThemeRepository(userDefaults: userDefaults)
}

func settingsRepositoryFactory(userDefaults: UserDefaults? = nil) -> SettingsRepository {
    return SettingsRepository(userDefaults: userDefaults)
}

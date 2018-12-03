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
    feed: Feed = feedFactory(),
    feedRepository: DatabaseUseCase = FakeDatabaseUseCase(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    tagEditorViewController: @escaping () -> TagEditorViewController = { tagEditorViewControllerFactory() }
    ) -> FeedViewController {
    return FeedViewController(
        feed: feed,
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
    feedService: FeedService = FakeFeedService(),
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    findFeedViewController: @escaping () -> FindFeedViewController = { findFeedViewControllerFactory() },
    feedViewController: @escaping (Feed) -> FeedViewController = { feed in feedViewControllerFactory(feed: feed) },
    settingsViewController: @escaping () -> SettingsViewController = { settingsViewControllerFactory() },
    articleListController: @escaping (Feed) -> ArticleListController = { feed in articleListControllerFactory(feed: feed) }
    ) -> FeedListController {
    return FeedListController(
        feedService: feedService,
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

func settingsViewControllerFactory(
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    settingsRepository: SettingsRepository = settingsRepositoryFactory(),
    opmlService: OPMLService = FakeOPMLService(),
    mainQueue: FakeOperationQueue = FakeOperationQueue(),
    documentationViewController: @escaping (Documentation) -> DocumentationViewController = { docs in documentationViewControllerFactory(documentation: docs) }
    ) -> SettingsViewController {
    return SettingsViewController(
        themeRepository: themeRepository,
        settingsRepository: settingsRepository,
        opmlService: opmlService,
        mainQueue: mainQueue,
        documentationViewController: documentationViewController
    )
}

func documentationViewControllerFactory(
    documentation: Documentation = .libraries,
    themeRepository: ThemeRepository = themeRepositoryFactory(),
    htmlViewController: HTMLViewController = htmlViewControllerFactory()
    ) -> DocumentationViewController {
    return DocumentationViewController(
        documentation: documentation,
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
    splitViewController: SplitViewController = splitViewControllerFactory(),
    feedsTableViewController: @escaping () -> FeedListController = { feedsTableViewControllerFactory() },
    blankViewController: @escaping () -> BlankViewController = { blankViewControllerFactory() }
    ) -> BootstrapWorkFlow {
    return BootstrapWorkFlow(
        window: window,
        splitViewController: splitViewController,
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

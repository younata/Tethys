import Foundation
import TethysKit
import Swinject

public func configure(container: Container) {
    container.register(UnreadCounter.self) { _ in
        let unreadCounter = UnreadCounter(frame: CGRect.zero)
        unreadCounter.translatesAutoresizingMaskIntoConstraints = false
        return unreadCounter
    }

    container.register(TagPickerView.self) { _ in
        let tagPicker = TagPickerView(frame: CGRect.zero)
        tagPicker.translatesAutoresizingMaskIntoConstraints = false
        return tagPicker
    }

    container.register(UserDefaults.self) { _ in return UserDefaults.standard }

    container.register(QuickActionRepository.self) { _ in return UIApplication.shared }.inObjectScope(.container)

    container.register(ThemeRepository.self) { r in
        return ThemeRepository(userDefaults: r.resolve(UserDefaults.self) ?? nil)
    }.inObjectScope(.container)

    container.register(SettingsRepository.self) { r in
        return SettingsRepository(userDefaults: r.resolve(UserDefaults.self) ?? nil)
    }.inObjectScope(.container)

    container.register(BackgroundFetchHandler.self) { r in
        return DefaultBackgroundFetchHandler(feedRepository: r.resolve(DatabaseUseCase.self)!)
    }

    container.register(Bootstrapper.self) { r, window, splitController in
        return BootstrapWorkFlow(
            window: window,
            feedRepository: r.resolve(DatabaseUseCase.self)!,
            migrationUseCase: r.resolve(MigrationUseCase.self)!,
            splitViewController: splitController,
            migrationViewController: { r.resolve(MigrationViewController.self)! },
            feedsTableViewController: { r.resolve(FeedsTableViewController.self)!},
            articleViewController: { r.resolve(ArticleViewController.self)! }
        )
    }

    container.register(ArticleUseCase.self) { r in
        return DefaultArticleUseCase(
            feedRepository: r.resolve(DatabaseUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!,
            articleService: r.resolve(ArticleService.self)!
        )
    }

    container.register(DocumentationUseCase.self) { r in
        return DefaultDocumentationUseCase(
            themeRepository: r.resolve(ThemeRepository.self)!
        )
    }

    container.register(ArticleCellController.self) { r, alwaysHideUnread in
        return DefaultArticleCellController(
            hideUnread: alwaysHideUnread,
            articleService: r.resolve(ArticleService.self)!,
            settingsRepository: r.resolve(SettingsRepository.self)!
        )
    }

    registerViewControllers(container: container)
}

private func registerViewControllers(container: Container) {
    container.register(ArticleListController.self) { r in
        return ArticleListController(
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            feedRepository: r.resolve(DatabaseUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!,
            settingsRepository: r.resolve(SettingsRepository.self)!,
            articleCellController: r.resolve(ArticleCellController.self, argument: false)!,
            articleViewController: { r.resolve(ArticleViewController.self)! },
            generateBookViewController: { r.resolve(GenerateBookViewController.self)! }
        )
    }

    container.register(ArticleViewController.self) { r in
        return ArticleViewController(
            themeRepository: r.resolve(ThemeRepository.self)!,
            articleUseCase: r.resolve(ArticleUseCase.self)!,
            htmlViewController: { r.resolve(HTMLViewController.self)! },
            articleListController: { r.resolve(ArticleListController.self)! }
        )
    }

    container.register(ChapterOrganizerController.self) { r in
        return ChapterOrganizerController(
            themeRepository: r.resolve(ThemeRepository.self)!,
            settingsRepository: r.resolve(SettingsRepository.self)!,
            articleCellController: r.resolve(ArticleCellController.self, argument: true)!,
            articleListController: { r.resolve(ArticleListController.self)! }
        )
    }

    container.register(DocumentationViewController.self) { r in
        return DocumentationViewController(
            documentationUseCase: r.resolve(DocumentationUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!,
            htmlViewController: r.resolve(HTMLViewController.self)!
        )
    }

    container.register(FeedsListController.self) { r in
        return FeedsListController(
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            themeRepository: r.resolve(ThemeRepository.self)!
        )
    }

    container.register(FeedsTableViewController.self) { r in
        return FeedsTableViewController(
            feedRepository: r.resolve(DatabaseUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!,
            settingsRepository: r.resolve(SettingsRepository.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            findFeedViewController: { r.resolve(FindFeedViewController.self)! },
            feedViewController: { r.resolve(FeedViewController.self)! },
            settingsViewController: { r.resolve(SettingsViewController.self)! },
            articleListController: { r.resolve(ArticleListController.self)! }
        )
    }

    container.register(FeedViewController.self) { r in
        return FeedViewController(
            feedRepository: r.resolve(DatabaseUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!,
            tagEditorViewController: { r.resolve(TagEditorViewController.self)! }
        )
    }

    container.register(FindFeedViewController.self) { r in
        return FindFeedViewController(
            importUseCase: r.resolve(ImportUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!,
            analytics: r.resolve(Analytics.self)!
        )
    }

    container.register(GenerateBookViewController.self) { r in
        return GenerateBookViewController(
            themeRepository: r.resolve(ThemeRepository.self)!,
            generateBookUseCase: r.resolve(GenerateBookUseCase.self)!,
            chapterOrganizer: r.resolve(ChapterOrganizerController.self)!
        )
    }

    container.register(HTMLViewController.self) { r in
        return HTMLViewController(themeRepository: r.resolve(ThemeRepository.self)!)
    }

    container.register(MigrationViewController.self) { r in
        return MigrationViewController(
            migrationUseCase: r.resolve(MigrationUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!
        )
    }

    container.register(SettingsViewController.self) { r in
        return SettingsViewController(
            themeRepository: r.resolve(ThemeRepository.self)!,
            settingsRepository: r.resolve(SettingsRepository.self)!,
            quickActionRepository: r.resolve(QuickActionRepository.self)!,
            databaseUseCase: r.resolve(DatabaseUseCase.self)!,
            opmlService: r.resolve(OPMLService.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            documentationViewController: { r.resolve(DocumentationViewController.self)! }
        )
    }

    container.register(SplitViewController.self) { r in
        return SplitViewController(themeRepository: r.resolve(ThemeRepository.self)!)
    }

    container.register(TagEditorViewController.self) { r in
        return TagEditorViewController(
            feedRepository: r.resolve(DatabaseUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!
        )
    }
}

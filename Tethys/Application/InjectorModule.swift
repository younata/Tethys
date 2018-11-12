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
    }

    container.register(SettingsRepository.self) { r in
        return SettingsRepository(userDefaults: r.resolve(UserDefaults.self) ?? nil)
    }

    container.register(BackgroundFetchHandler.self) { r in
        return DefaultBackgroundFetchHandler(feedRepository: r.resolve(DatabaseUseCase.self)!)
    }

    container.register(NotificationHandler.self) { r in
        return LocalNotificationHandler(feedRepository: r.resolve(DatabaseUseCase.self)!)
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
            themeRepository: r.resolve(ThemeRepository.self)!
        )
    }

    container.register(DocumentationUseCase.self) { r in
        return DefaultDocumentationUseCase(
            themeRepository: r.resolve(ThemeRepository.self)!
        )
    }

    // View Controllers

    container.register(SplitViewController.self) { r in
        return SplitViewController(themeRepository: r.resolve(ThemeRepository.self)!)
    }

    container.register(MigrationViewController.self) { r in
        return MigrationViewController(
            migrationUseCase: r.resolve(MigrationUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!
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

    container.register(FindFeedViewController.self) { r in
        return FindFeedViewController(
            importUseCase: r.resolve(ImportUseCase.self)!,
            themeRepository: r.resolve(ThemeRepository.self)!,
            analytics: r.resolve(Analytics.self)!
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

    container.register(HTMLViewController.self) { r in
        return HTMLViewController(themeRepository: r.resolve(ThemeRepository.self)!)
    }
}

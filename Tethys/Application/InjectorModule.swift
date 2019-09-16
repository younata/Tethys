import UIKit
import Swinject
import TethysKit
import AuthenticationServices

public func configure(container: Container) {    container.register(TagPickerView.self) { _ in
        let tagPicker = TagPickerView(frame: CGRect.zero)
        tagPicker.translatesAutoresizingMaskIntoConstraints = false
        return tagPicker
    }

    container.register(UserDefaults.self) { _ in return UserDefaults.standard }

    container.register(Messenger.self) { _ in return SwiftMessenger() }

    container.register(SettingsRepository.self) { r in
        return SettingsRepository(userDefaults: r.resolve(UserDefaults.self) ?? nil)
    }.inObjectScope(.container)

    container.register(ArticleUseCase.self) { r in
        return DefaultArticleUseCase(
            articleService: r.resolve(ArticleService.self)!
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
    container.register(ArticleListController.self) { r, feed in
        return ArticleListController(
            feed: feed,
            feedService: r.resolve(FeedService.self)!,
            articleService: r.resolve(ArticleService.self)!,
            notificationCenter: .default,
            articleCellController: r.resolve(ArticleCellController.self, argument: false)!,
            articleViewController: { article in r.resolve(ArticleViewController.self, argument: article)! }
        )
    }

    container.register(ArticleViewController.self) { r, article in
        return ArticleViewController(
            article: article,
            articleUseCase: r.resolve(ArticleUseCase.self)!,
            htmlViewController: { r.resolve(HTMLViewController.self)! }
        )
    }

    container.register(AugmentedRealityEasterEggViewController.self) { r in
        return AugmentedRealityEasterEggViewController(
            feedListControllerFactory: { r.resolve(FeedListController.self)! }
        )
    }

    container.register(DocumentationViewController.self) { r, documentation in
        return DocumentationViewController(
            documentation: documentation,
            htmlViewController: r.resolve(HTMLViewController.self)!
        )
    }

    container.register(FeedListController.self) { r in
        return FeedListController(
            feedService: r.resolve(FeedService.self)!,
            settingsRepository: r.resolve(SettingsRepository.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            notificationCenter: .default,
            findFeedViewController: { r.resolve(FindFeedViewController.self)! },
            feedViewController: { feed in r.resolve(FeedViewController.self, argument: feed)! },
            settingsViewController: { r.resolve(SettingsViewController.self)! },
            articleListController: { feed in r.resolve(ArticleListController.self, argument: feed)! }
        )
    }

    container.register(FeedViewController.self) { r, feed in
        return FeedViewController(
            feed: feed,
            feedService: r.resolve(FeedService.self)!,
            tagEditorViewController: { r.resolve(TagEditorViewController.self)! }
        )
    }

    container.register(FindFeedViewController.self) { r in
        return FindFeedViewController(
            importUseCase: r.resolve(ImportUseCase.self)!,
            analytics: r.resolve(Analytics.self)!,
            notificationCenter: .default
        )
    }

    container.register(HTMLViewController.self) { _ in
        return HTMLViewController()
    }

    container.register(LoginController.self) { r in
        return OAuthLoginController(
            accountService: r.resolve(AccountService.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            clientId: Bundle.main.infoDictionary?["InoreaderClientID"] as? String ?? "",
            authenticationSessionFactory: ASWebAuthenticationSession.init
        )
    }

    container.register(SettingsViewController.self) { r in
        return SettingsViewController(
            settingsRepository: r.resolve(SettingsRepository.self)!,
            opmlService: r.resolve(OPMLService.self)!,
            mainQueue: r.resolve(OperationQueue.self, name: kMainQueue)!,
            accountService: r.resolve(AccountService.self)!,
            messenger: r.resolve(Messenger.self)!,
            loginController: r.resolve(LoginController.self)!,
            documentationViewController: { documentation in
                return r.resolve(DocumentationViewController.self, argument: documentation)!
            },
            arViewController: { r.resolve(AugmentedRealityEasterEggViewController.self)! }
        )
    }

    container.register(SplitViewController.self) { _ in
        return SplitViewController()
    }

    container.register(TagEditorViewController.self) { r in
        return TagEditorViewController(
            feedService: r.resolve(FeedService.self)!
        )
    }
}

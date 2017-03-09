import Foundation
import Ra

public final class InjectorModule: Ra.InjectorModule {
    public func configureInjector(injector: Injector) {
        // Views
        injector.bind(UnreadCounter.self) { _ in
            let unreadCounter = UnreadCounter(frame: CGRect.zero)
            unreadCounter.translatesAutoresizingMaskIntoConstraints = false
            return unreadCounter
        }

        injector.bind(TagPickerView.self) { _ in
            let tagPicker = TagPickerView(frame: CGRect.zero)
            tagPicker.translatesAutoresizingMaskIntoConstraints = false
            return tagPicker
        }

        injector.bind(Bundle.self, to: Bundle.main)

        let app = UIApplication.shared
        injector.bind(QuickActionRepository.self, to: app)

        injector.bind(ThemeRepository.self, to: ThemeRepository(injector: injector))

        let userDefaults = UserDefaults.standard
        injector.bind(SettingsRepository.self, to: SettingsRepository(userDefaults: userDefaults))

        injector.bind(BackgroundFetchHandler.self, toBlock: DefaultBackgroundFetchHandler.init)

        injector.bind(NotificationHandler.self, toBlock: LocalNotificationHandler.init)

        injector.bind(ArticleUseCase.self, toBlock: DefaultArticleUseCase.init)

        injector.bind(FileManager.self, to: FileManager.default)

        injector.bind(DocumentationUseCase.self, toBlock: DefaultDocumentationUseCase.init)
    }

    public init() {}
}

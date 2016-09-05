import Foundation
import Ra

public final class InjectorModule: Ra.InjectorModule {
    public func configureInjector(_ injector: Injector) {
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

        injector.bind(string: Bundle.self, to: Bundle.mainBundle())

        let app = UIApplication.shared
        injector.bind(string: QuickActionRepository.self, to: app)

        injector.bind(string: ThemeRepository.self, to: ThemeRepository(injector: injector))

        let userDefaults = UserDefaults.standard
        injector.bind(string: SettingsRepository.self, to: SettingsRepository(userDefaults: userDefaults))

        injector.bind(BackgroundFetchHandler.self, to: DefaultBackgroundFetchHandler.init)

        injector.bind(NotificationHandler.self, to: LocalNotificationHandler.init)

        injector.bind(ArticleUseCase.self, to: DefaultArticleUseCase.init)

        injector.bind(string: FileManager.self, to: FileManager.defaultManager())
    }

    public init() {}
}

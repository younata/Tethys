import Foundation
import Ra

public final class InjectorModule: Ra.InjectorModule {
    public func configureInjector(injector: Injector) {
        // Views
        injector.bind(kind: UnreadCounter.self) { _ in
            let unreadCounter = UnreadCounter(frame: CGRect.zero)
            unreadCounter.translatesAutoresizingMaskIntoConstraints = false
            return unreadCounter
        }

        injector.bind(kind: TagPickerView.self) { _ in
            let tagPicker = TagPickerView(frame: CGRect.zero)
            tagPicker.translatesAutoresizingMaskIntoConstraints = false
            return tagPicker
        }

        injector.bind(kind: Bundle.self, toInstance: Bundle.main)

        let app = UIApplication.shared
        injector.bind(kind: QuickActionRepository.self, toInstance: app)

        injector.bind(kind: ThemeRepository.self, toInstance: ThemeRepository(injector: injector))

        let userDefaults = UserDefaults.standard
        injector.bind(kind: SettingsRepository.self, toInstance: SettingsRepository(userDefaults: userDefaults))

        injector.bind(kind: BackgroundFetchHandler.self, to: DefaultBackgroundFetchHandler.init)

        injector.bind(kind: NotificationHandler.self, to: LocalNotificationHandler.init)

        injector.bind(kind: ArticleUseCase.self, to: DefaultArticleUseCase.init)

        injector.bind(kind: FileManager.self, toInstance: FileManager.default)
    }

    public init() {}
}

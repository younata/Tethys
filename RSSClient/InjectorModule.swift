import Foundation
import Ra

public class InjectorModule: Ra.InjectorModule {
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

        injector.bind(ImportUseCase.self) { DefaultImportUseCase(injector: $0) }

        let app = UIApplication.sharedApplication()
        injector.bind(UrlOpener.self, toInstance: app)
        injector.bind(QuickActionRepository.self, toInstance: app)

        injector.bind(ThemeRepository.self, toInstance: ThemeRepository(injector: injector))

        let userDefaults = NSUserDefaults.standardUserDefaults()
        injector.bind(SettingsRepository.self, toInstance: SettingsRepository(userDefaults: userDefaults))

        injector.bind(BackgroundFetchHandler.self) { DefaultBackgroundFetchHandler(injector: $0) }

        injector.bind(NotificationHandler.self) { LocalNotificationHandler(injector: $0) }

        injector.bind(FeedFinder.self, toInstance: WebFeedFinder())

        injector.bind(NSFileManager.self, toInstance: NSFileManager.defaultManager())
    }

    public init() {}
}

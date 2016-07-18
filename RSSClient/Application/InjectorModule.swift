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

        injector.bind(NSBundle.self, toInstance: NSBundle.mainBundle())

        injector.bind(DocumentationUseCase.self, to: DefaultDocumentationUseCase.init)

        let app = UIApplication.sharedApplication()
        injector.bind(QuickActionRepository.self, toInstance: app)

        injector.bind(ThemeRepository.self, toInstance: ThemeRepository(injector: injector))

        let userDefaults = NSUserDefaults.standardUserDefaults()
        injector.bind(SettingsRepository.self, toInstance: SettingsRepository(userDefaults: userDefaults))

        injector.bind(BackgroundFetchHandler.self, to: DefaultBackgroundFetchHandler.init)

        injector.bind(NotificationHandler.self, to: LocalNotificationHandler.init)

        injector.bind(ArticleUseCase.self, to: DefaultArticleUseCase.init)

        injector.bind(NSFileManager.self, toInstance: NSFileManager.defaultManager())
    }

    public init() {}
}

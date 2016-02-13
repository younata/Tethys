import Foundation
import Ra

public class InjectorModule: Ra.InjectorModule {
    public func configureInjector(injector: Injector) {
        // Views
        injector.bind(UnreadCounter.self) { _ in
            let unreadCounter = UnreadCounter(frame: CGRectZero)
            unreadCounter.translatesAutoresizingMaskIntoConstraints = false
            return unreadCounter
        }

        injector.bind(TagPickerView.self) { _ in
            let tagPicker = TagPickerView(frame: CGRectZero)
            tagPicker.translatesAutoresizingMaskIntoConstraints = false
            return tagPicker
        }

        injector.bind(UrlOpener.self, toInstance: UIApplication.sharedApplication())

        injector.bind(QuickActionRepository.self, toInstance: UIApplication.sharedApplication())

        let themeRepository = ThemeRepository(injector: injector)
        injector.bind(ThemeRepository.self, toInstance: themeRepository)

        let settingsRepository = SettingsRepository(userDefaults: NSUserDefaults.standardUserDefaults())
        injector.bind(SettingsRepository.self, toInstance: settingsRepository)

        let feedFinder = WebFeedFinder()
        injector.bind(FeedFinder.self, toInstance: feedFinder)

        injector.bind(NSFileManager.self, toInstance: NSFileManager.defaultManager())
    }

    public init() {}
}

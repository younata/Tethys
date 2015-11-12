import Foundation
import Ra

public class InjectorModule : Ra.InjectorModule {
    public func configureInjector(injector: Injector) {
        // Views
        injector.bind(UnreadCounter.self) {
            let unreadCounter = UnreadCounter(frame: CGRectZero);
            unreadCounter.translatesAutoresizingMaskIntoConstraints = false;
            return unreadCounter;
        }

        injector.bind(TagPickerView.self) {
            let tagPicker = TagPickerView(frame: CGRectZero)
            tagPicker.translatesAutoresizingMaskIntoConstraints = false
            return tagPicker
        }

        injector.bind(UrlOpener.self, to: UIApplication.sharedApplication())

        let themeRepository = ThemeRepository(injector: injector)
        injector.bind(ThemeRepository.self, to: themeRepository)

        let settingsRepository = SettingsRepository(userDefaults: NSUserDefaults.standardUserDefaults())
        injector.bind(SettingsRepository.self, to: settingsRepository)

        let feedFinder = WebFeedFinder()
        injector.bind(FeedFinder.self, to: feedFinder)

        injector.bind(NSFileManager.self, to: NSFileManager.defaultManager())
    }

    public init() {}
}
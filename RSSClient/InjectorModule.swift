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

        let feedFinder = WebFeedFinder()
        injector.bind(FeedFinder.self, to: feedFinder)
    }

    public init() {}
}
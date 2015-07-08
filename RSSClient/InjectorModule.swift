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
    }

    public init() {}
}
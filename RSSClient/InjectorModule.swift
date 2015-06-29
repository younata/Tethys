import Foundation
import Ra
import CoreSpotlight

public let kBackgroundManagedObjectContext = "kBackgroundManagedObjectContext"

public let kMainQueue = "kMainQueue"
public let kBackgroundQueue = "kBackgroundQueue"

public class InjectorModule : Ra.InjectorModule {
    public func configureInjector(injector: Injector) {
        // Operation Queues
        injector.bind(kMainQueue, to: NSOperationQueue.mainQueue())

        if #available(iOS 9.0, *) {
            injector.bind(SearchIndex.self, to: CSSearchableIndex.defaultSearchableIndex())
        }

        let backgroundQueue = NSOperationQueue()
        backgroundQueue.qualityOfService = NSQualityOfService.Utility
        injector.bind(kBackgroundQueue, to: backgroundQueue)

        // DataManager
        if let dataManager = injector.create(DataManager.self) as? DataManager {
            injector.bind(DataManager.self, to: dataManager)

            injector.bind(kBackgroundManagedObjectContext, to: dataManager.backgroundObjectContext)
        }

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
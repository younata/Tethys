import Foundation
import Ra

public let kBackgroundManagedObjectContext = "kBackgroundManagedObjectContext"

public let kMainQueue = "kMainQueue"
public let kBackgroundQueue = "kBackgroundQueue"

public class InjectorModule : Ra.InjectorModule {
    public func configureInjector(injector: Injector) {
        // Operation Queues
        injector.bind(kMainQueue, to: NSOperationQueue.mainQueue())

        let backgroundQueue = NSOperationQueue()
        backgroundQueue.qualityOfService = NSQualityOfService.Utility
        injector.bind(kBackgroundQueue, to: backgroundQueue)

        // DataManager
        if let dataManager = injector.create(DataManager.self) as? DataManager {
            dataManager.configure()
            injector.bind(DataManager.self, to: dataManager)

            injector.bind(kBackgroundManagedObjectContext, to: dataManager.backgroundObjectContext)
        }

        // Views

        injector.bind(UnreadCounter.self) {
            let unreadCounter = UnreadCounter(frame: CGRectZero);
            unreadCounter.setTranslatesAutoresizingMaskIntoConstraints(false);
            return unreadCounter;
        }

        injector.bind(LoadingView.self) {
            let loadingView = LoadingView(frame: CGRectZero)
            loadingView.setTranslatesAutoresizingMaskIntoConstraints(false)
            return loadingView
        }

        injector.bind(TagPickerView.self) {
            let tagPicker = TagPickerView(frame: CGRectZero)
            tagPicker.setTranslatesAutoresizingMaskIntoConstraints(false)
            return tagPicker
        }
    }

    public init() {}
}
import Foundation
import Ra

let kBackgroundManagedObjectContext = "kBackgroundManagedObjectContext"

let kMainQueue = "kMainQueue"
let kBackgroundQueue = "kBackgroundQueue"

class InjectorModule : Ra.InjectorModule {
    func configureInjector(injector: Injector) {
        // Operation Queues
        injector.bind(kMainQueue, to: NSOperationQueue.mainQueue())

        let backgroundQueue = NSOperationQueue()
        backgroundQueue.qualityOfService = NSQualityOfService.Utility
        injector.bind(kBackgroundQueue, to: backgroundQueue)

        // DataManager
        let dataManager = injector.create(DataManager.self) as! DataManager
        dataManager.configure()
        injector.bind(DataManager.self, to: dataManager)

        injector.bind(NSFileManager.self, to: NSFileManager.defaultManager())

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
        
        // Managed Object Contexts
        injector.bind(kBackgroundManagedObjectContext, to: dataManager.backgroundObjectContext)
    }
}
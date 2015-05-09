import Foundation
import Ra

let kMainManagedObjectContext = "kMainManagedObjectContext"
let kBackgroundManagedObjectContext = "kBackgroundManagedObjectContext"

class InjectorModule : Ra.InjectorModule {
    func configureInjector(injector: Ra.Injector) {
        let dataManager = DataManager()
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
        injector.bind(kMainManagedObjectContext, to: dataManager.managedObjectContext)
        injector.bind(kBackgroundManagedObjectContext, to: dataManager.backgroundObjectContext)
    }
}
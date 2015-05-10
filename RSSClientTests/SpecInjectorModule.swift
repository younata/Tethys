import Foundation
import Ra

class SpecInjectorModule : InjectorModule {
    override func configureInjector(injector: Injector) {
        super.configureInjector(injector)
        let dataManager = DataManagerMock()
        injector.bind(DataManager.self, to: dataManager)
        injector.bind(kMainManagedObjectContext, to: dataManager.managedObjectContext)
        injector.bind(kBackgroundManagedObjectContext, to: dataManager.backgroundObjectContext)

        let mainQueue = FakeOperationQueue()
        injector.bind(kMainQueue, to: mainQueue)
        let backgroundQueue = FakeOperationQueue()
        injector.bind(kBackgroundQueue, to: backgroundQueue)
    }
}
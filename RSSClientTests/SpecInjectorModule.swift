import Foundation
import Ra
import rNews

public class SpecInjectorModule : rNews.InjectorModule {
    public override func configureInjector(injector: Injector) {
        super.configureInjector(injector)
        let dataManager = DataManagerMock()
        injector.bind(DataManager.self, to: dataManager)
        injector.bind(kBackgroundManagedObjectContext, to: dataManager.backgroundObjectContext)

        let mainQueue = FakeOperationQueue()
        injector.bind(kMainQueue, to: mainQueue)
        let backgroundQueue = FakeOperationQueue()
        injector.bind(kBackgroundQueue, to: backgroundQueue)
    }
}
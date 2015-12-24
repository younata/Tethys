import Foundation
import Ra
import rNews
import rNewsKit

public class SpecInjectorModule : rNews.InjectorModule {
    public override func configureInjector(injector: Injector) {
        super.configureInjector(injector)
        let mainQueue = FakeOperationQueue()
        injector.bind(kMainQueue, toInstance: mainQueue)
        let backgroundQueue = FakeOperationQueue()
        injector.bind(kBackgroundQueue, toInstance: backgroundQueue)
    }
}
import Foundation
import Ra
import rNews
import rNewsKit

public class SpecInjectorModule : rNews.InjectorModule {
    public override func configureInjector(injector: Injector) {
        super.configureInjector(injector)
        injector.bind(kMainQueue, toInstance: FakeOperationQueue())
        injector.bind(kBackgroundQueue, toInstance: FakeOperationQueue())
    }
}
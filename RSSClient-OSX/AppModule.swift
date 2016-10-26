import AppKit
import Ra

public let kMainMenu = "kMainMenuKey"

public final class AppModule: InjectorModule {
    public func configureInjector(injector: Injector) {
        injector.bind(string: kMainMenu, toInstance: NSApp.mainMenu!)
    }

    public init() {}
}

import AppKit
import Ra

public let kMainMenu = "kMainMenuKey"

public class AppModule: InjectorModule {
    public func configureInjector(injector: Injector) {
        injector.bind(kMainMenu, to: NSApp.mainMenu!)
    }

    public init() {}
}

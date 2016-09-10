import AppKit
import Ra

public let kMainMenu = "kMainMenuKey"

public final class AppModule: InjectorModule {
    public func configureInjector(_ injector: Injector) {
        injector.bind(kMainMenu, to: NSApp.mainMenu!)
    }

    public init() {}
}

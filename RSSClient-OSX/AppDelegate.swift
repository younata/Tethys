import Cocoa
import rNewsKit
import Ra

@NSApplicationMain
public final class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow? {
        didSet {
            self.windowController = NSWindowController(window: window)
        }
    }

    @IBOutlet public var mainController: MainController? = nil

    var windowController: NSWindowController? = nil

    public func applicationDidFinishLaunching(_ aNotification: Notification) {
        let injector = Injector(module: KitModule(), AppModule())
        mainController?.window = window
        mainController?.configure(injector)
    }

    public func applicationWillTerminate(_ aNotification: Notification) {
    }

    public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return nil
    }

    public func openFile(_ filename: String, finish: ([Feed]) -> (Void)) -> Bool {
        return false
    }

    public func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        return false
    }

    public func application(_ sender: Any, openFileWithoutUI filename: String) -> Bool {
        return openFile(filename) {(_) in }
    }
}

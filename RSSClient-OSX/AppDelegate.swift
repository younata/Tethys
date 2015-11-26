import Cocoa
import rNewsKit
import Ra

@NSApplicationMain
public class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow? {
        didSet {
            self.windowController = NSWindowController(window: window)
        }
    }

    @IBOutlet public var mainController: MainController? = nil

    var windowController: NSWindowController? = nil

    public func applicationDidFinishLaunching(aNotification: NSNotification) {
        let injector = Injector(module: KitModule(), AppModule())
        mainController?.window = window
        mainController?.configure(injector)
    }

    public func applicationWillTerminate(aNotification: NSNotification) {
    }

    public func applicationDockMenu(sender: NSApplication) -> NSMenu? {
        return nil
    }

    func openFile(filename: String, finish: ([Feed]) -> (Void)) -> Bool {
        return false
    }

    public func application(sender: NSApplication, openFile filename: String) -> Bool {
        return false
    }

    public func application(sender: AnyObject, openFileWithoutUI filename: String) -> Bool {
        return openFile(filename) {(_) in }
    }
}

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
        /*
        if let string = NSString(contentsOfFile: filename, encoding: NSUTF8StringEncoding, error: nil) {
            let semaphore = dispatch_semaphore_create(0)
            var ret = false
            let opmlParser = OPMLParser(text: string)
            opmlParser.success {(_) in
                ret = true
                dispatch_semaphore_signal(semaphore)
            }
            opmlParser.failure {(_) in
                dispatch_semaphore_signal(semaphore)
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            if ret {
                DataManager.sharedInstance().importOPML(NSURL(fileURLWithPath: filename)!, progress: {(_) in }, completion: finish)
            }
            return ret
        }*/
        return false
    }
    
    public func application(sender: NSApplication, openFile filename: String) -> Bool {
        return false
        //return openFile(filename) {(feeds) in }
    }
    
    public func application(sender: AnyObject, openFileWithoutUI filename: String) -> Bool {
        return openFile(filename) {(_) in }
    }
}


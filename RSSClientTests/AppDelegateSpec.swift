import Quick
import Nimble

class DataManagerMock : DataManager {
    override func importOPML(opml: NSURL) {
        
    }
    
    override func importOPML(opml: NSURL, progress: (Double) -> Void, completion: ([Feed]) -> Void) {
    }
    
    override func writeOPML() {
        
    }
    
    override func allTags(#managedObjectContext: NSManagedObjectContext?) -> [String] {
        return []
    }
    
    override func feeds(#managedObjectContext: NSManagedObjectContext?) -> [Feed] {
        return []
    }
    
    override func feedsMatchingTag(tag: String?, managedObjectContext: NSManagedObjectContext?, allowIncompleteTags: Bool) -> [Feed] {
        return []
    }
    
    override func updateFeeds(completion: (NSError?) -> (Void)) {
        completion(nil)
    }
    
    override func updateFeedsInBackground(completion: (NSError?) -> (Void)) {
        completion(nil)
    }
    
    override func updateFeeds(feeds: [Feed], completion: (NSError?) -> (Void), backgroundFetch: Bool) {
        completion(nil)
    }
}

class AppDelegateSpec: QuickSpec {
    override func spec() {
        var subject: AppDelegate! = nil
        
        let application = UIApplication.sharedApplication()
        
        beforeEach {
            subject = AppDelegate()
            subject.window = UIWindow(frame: CGRectMake(0, 0, 320, 480))
            // Apparently, calling "-makeKeyAndVisible" on a window in test will cause a crash.
            subject.dataManager = DataManagerMock(testing: true)
        }
        
        describe("-application:didFinishLaunchingWithOptions:") {
            beforeEach {
                subject.application(application, didFinishLaunchingWithOptions: nil)
                return
            }

            describe("window view controllers") {
                var splitViewController: UISplitViewController! = nil
                
                beforeEach {
                    splitViewController = subject.window.rootViewController as UISplitViewController
                }

                it("should have a splitViewController as the rootViewController") {
                    expect(subject.window.rootViewController).to(beAnInstanceOf(UISplitViewController.self))
                }
                
                describe("master view controller") {
                    var vc: UIViewController! = nil
                    
                    beforeEach {
                        vc = splitViewController.viewControllers[0] as UIViewController
                    }
                
                    it("should be an instance of UINavigationController") {
                        expect(vc).to(beAnInstanceOf(UINavigationController.self))
                    }
                    
                    it("should have a FeedsTableViewController as the root controller") {
                        let nc = vc as UINavigationController
                        expect(nc.viewControllers.first! as UIViewController).to(beAnInstanceOf(FeedsTableViewController.self))
                    }
                }

                describe("detail view controller") {
                    var vc: UIViewController! = nil
                    
                    beforeEach {
                        vc = splitViewController.viewControllers[1] as UIViewController
                    }
                    
                    it("should be an instance of UINavigationController") {
                        expect(vc).to(beAnInstanceOf(UINavigationController.self))
                    }
                    
                    it("should have an ArticleViewController as the root controller") {
                        let nc = vc as UINavigationController
                        expect(nc.viewControllers.first! as UIViewController).to(beAnInstanceOf(ArticleViewController.self))
                    }
                }
            }
        }
    }
}

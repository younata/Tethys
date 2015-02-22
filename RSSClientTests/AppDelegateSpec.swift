import Quick
import Nimble
import Ra

class AppDelegateSpec: QuickSpec {
    override func spec() {
        var subject: AppDelegate! = nil
        
        let application = UIApplication.sharedApplication()
        var injector : Ra.Injector! = nil
        
        beforeEach {
            subject = AppDelegate()

            injector = Ra.Injector()
            let dataManager = DataManager(dataHelper: CoreDataHelper())
            injector.bind(DataManager.self) {
                dataManager
            }
            injector.bind(kMainManagedObjectContext, to: dataManager.managedObjectContext)
            injector.bind(kBackgroundManagedObjectContext, to: dataManager.backgroundObjectContext)

            subject.anInjector = injector
            subject.window = UIWindow(frame: CGRectMake(0, 0, 320, 480))
            // Apparently, calling "-makeKeyAndVisible" on a window in test will cause a crash.
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

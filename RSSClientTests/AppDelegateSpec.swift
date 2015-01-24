import Quick
import Nimble

class AppDelegateSpec: QuickSpec {
    override func spec() {
        var subject: AppDelegate! = nil
        
        beforeEach {
            subject = AppDelegate()
        }
        
        describe("-application:didFinishLaunchingWithOptions:") {
            it("should have a window") {
                expect(subject.window).toNot(beNil())
            }
            
            describe("window view controllers") {
                var splitViewController: UISplitViewController! = nil
                
                beforeEach {
                    splitViewController = subject.window!.rootViewController as UISplitViewController
                }
                
                it("should have a splitViewController as the rootViewController") {
                    expect(subject.window!.rootViewController).to(beAnInstanceOf(UISplitViewController.self))
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
            }
        }
    }
}

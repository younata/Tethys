import Quick
import Nimble
import rNews

class SplitDelegateSpec: QuickSpec {
    override func spec() {
        let splitViewController = UISplitViewController()
        
        let master = UIViewController()
        let detail = UIViewController()
        
        var subject : SplitDelegate? = nil
        
        beforeEach {
            subject = SplitDelegate(splitViewController: splitViewController)
            splitViewController.delegate = subject
            splitViewController.viewControllers = [master, detail]
        }
        
        it("should hide the detail on startup") {
            expect(splitViewController.delegate!.splitViewController!(splitViewController, collapseSecondaryViewController: detail, ontoPrimaryViewController: master)).to(beTruthy())
        }
        
        describe("Changing from collapsed to not collapsed") {
            
            beforeEach {
                subject?.collapseDetailViewController = false
                splitViewController.showDetailViewController(detail, sender: self)
            }
            
            it("should show the detail") {
                expect(splitViewController.delegate!.splitViewController!(splitViewController, collapseSecondaryViewController: detail, ontoPrimaryViewController: master)).to(beFalsy())
            }
        }
    }
}

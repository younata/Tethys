import Quick
import Nimble
import rNews

class SplitViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SplitViewController! = nil
        
        let master = UIViewController()
        let detail = UIViewController()

        beforeEach {
            subject = SplitViewController()
            subject.viewControllers = [master, detail]
        }
        
        it("should hide the detail on startup") {
            expect(subject.delegate?.splitViewController!(subject, collapseSecondaryViewController: detail, ontoPrimaryViewController: master)).to(beTruthy())
        }
        
        describe("Changing from collapsed to not collapsed") {
            
            beforeEach {
                subject?.collapseDetailViewController = false
                subject.showDetailViewController(detail, sender: self)
            }
            
            it("should show the detail") {
                expect(subject.delegate?.splitViewController!(subject, collapseSecondaryViewController: detail, ontoPrimaryViewController: master)).to(beFalsy())
            }
        }
    }
}

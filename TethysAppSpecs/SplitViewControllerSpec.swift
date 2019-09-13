import Quick
import Nimble
import Tethys
import SafariServices

class SplitViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SplitViewController! = nil
        let master = UINavigationController(rootViewController: UIViewController())
        let detail = UINavigationController(rootViewController: UIViewController())

        beforeEach {
            subject = SplitViewController()
            subject.view.layoutIfNeeded()
            subject.viewControllers = [master, detail]
        }

        it("should hide the detail on startup") {
            expect(subject.delegate?.splitViewController!(subject, collapseSecondary: detail, onto: master)) == true
        }
        
        describe("Changing from collapsed to not collapsed") {
            
            beforeEach {
                subject?.collapseDetailViewController = false
                subject.showDetailViewController(detail, sender: self)
            }
            
            it("should show the detail") {
                expect(subject.delegate?.splitViewController!(subject, collapseSecondary: detail, onto: master)) == false
            }
        }
    }
}

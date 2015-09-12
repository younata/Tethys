import Quick
import Nimble
import rNews
import Ra

class SplitViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SplitViewController! = nil
        var themeRepository: FakeThemeRepository! = nil

        let master = UIViewController()
        let detail = UIViewController()

        beforeEach {
            let injector = Injector()

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, to: themeRepository)

            subject = injector.create(SplitViewController.self) as! SplitViewController
            subject.view.layoutIfNeeded()
            subject.viewControllers = [master, detail]
        }

        describe("when the theme changes") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should change the preferred status bar styling") {
                expect(subject.preferredStatusBarStyle()).to(equal(themeRepository.statusBarStyle))
            }
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

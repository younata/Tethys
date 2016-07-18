import Quick
import Nimble
import rNews
import Ra
import SafariServices

class SplitViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SplitViewController! = nil
        var themeRepository: FakeThemeRepository! = nil

        let master = UINavigationController(rootViewController: UIViewController())
        let detail = UINavigationController(rootViewController: UIViewController())

        beforeEach {
            let injector = Injector()

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(SplitViewController)!
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

            context("when an SFSafariViewController is on the master view controller") {
                beforeEach {
                    master.topViewController?.presentViewController(SFSafariViewController(URL: NSURL(string: "https://example.com")!), animated: false, completion: nil)
                }

                it("changes the preferredStatusBarStyle to black") {
                    expect(subject.preferredStatusBarStyle()) == UIStatusBarStyle.Default
                }
            }

            context("when an SFSafariViewController is on the detail view controller") {
                beforeEach {
                    detail.topViewController?.presentViewController(SFSafariViewController(URL: NSURL(string: "https://example.com")!), animated: false, completion: nil)
                }

                it("changes the preferredStatusBarStyle to black") {
                    expect(subject.preferredStatusBarStyle()) == UIStatusBarStyle.Default
                }
            }
        }

        it("should hide the detail on startup") {
            expect(subject.delegate?.splitViewController!(subject, collapseSecondaryViewController: detail, ontoPrimaryViewController: master)) == true
        }
        
        describe("Changing from collapsed to not collapsed") {
            
            beforeEach {
                subject?.collapseDetailViewController = false
                subject.showDetailViewController(detail, sender: self)
            }
            
            it("should show the detail") {
                expect(subject.delegate?.splitViewController!(subject, collapseSecondaryViewController: detail, ontoPrimaryViewController: master)) == false
            }
        }
    }
}

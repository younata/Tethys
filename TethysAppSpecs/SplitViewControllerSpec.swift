import Quick
import Nimble
import Tethys
import Ra
import SafariServices

class SplitViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SplitViewController! = nil
        var themeRepository: ThemeRepository! = nil

        let master = UINavigationController(rootViewController: UIViewController())
        let detail = UINavigationController(rootViewController: UIViewController())

        beforeEach {
            let injector = Injector()

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(ThemeRepository.self, to: themeRepository)

            subject = injector.create(SplitViewController.self)!
            subject.view.layoutIfNeeded()
            subject.viewControllers = [master, detail]
        }

        describe("when the theme changes") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should change the preferred status bar styling") {
                expect(subject.preferredStatusBarStyle).to(equal(themeRepository.statusBarStyle))
            }

            context("when an SFSafariViewController is on the master view controller") {
                beforeEach {
                    master.topViewController?.present(SFSafariViewController(url: URL(string: "https://example.com")!), animated: false, completion: nil)
                }

                it("changes the preferredStatusBarStyle to black") {
                    expect(subject.preferredStatusBarStyle) == UIStatusBarStyle.default
                }
            }

            context("when an SFSafariViewController is on the detail view controller") {
                beforeEach {
                    detail.topViewController?.present(SFSafariViewController(url: URL(string: "https://example.com")!), animated: false, completion: nil)
                }

                it("changes the preferredStatusBarStyle to black") {
                    expect(subject.preferredStatusBarStyle) == UIStatusBarStyle.default
                }
            }
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

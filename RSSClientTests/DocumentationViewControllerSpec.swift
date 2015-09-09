import Quick
import Nimble
import rNews
import Ra

class DocumentationViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: DocumentationViewController! = nil
        var themeRepository: FakeThemeRepository! = nil
        var navigationController: UINavigationController! = nil

        beforeEach {
            let injector = Injector()

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, to: themeRepository)

            subject = injector.create(DocumentationViewController.self) as! DocumentationViewController
            navigationController = UINavigationController(rootViewController: subject)
            subject.view.layoutIfNeeded()
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should update the navigation bar background") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
            }

            it("should update the view background") {
                expect(subject.view.backgroundColor).to(equal(themeRepository.backgroundColor))
            }
        }

        describe("configuring with a document") {
            describe("Query Feed") {
                beforeEach {
                    subject.configure(.QueryFeed)
                }

                it("should change the navigation title") {
                    expect(subject.navigationItem.title).to(equal("Query Feeds"))
                }
            }
        }
    }
}
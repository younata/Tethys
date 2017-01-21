import Quick
import Nimble
import UIKit
import SafariServices
import Tethys
import Ra

class DocumentationViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: DocumentationViewController!
        var fakeDocumentationUseCase: FakeDocumentationUseCase!
        var htmlViewController: HTMLViewController!
        var themeRepository: ThemeRepository!
        var navigationController: UINavigationController!

        beforeEach {
            let injector = Injector()

            fakeDocumentationUseCase = FakeDocumentationUseCase()
            injector.bind(kind: DocumentationUseCase.self, toInstance: fakeDocumentationUseCase)

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            htmlViewController = HTMLViewController(themeRepository: themeRepository)
            injector.bind(kind: HTMLViewController.self, toInstance: htmlViewController)

            subject = injector.create(kind: DocumentationViewController.self)

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should update the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
            }
        }

        describe("setting the documentation type") {
            let documentationType = Documentation.libraries
            beforeEach {
                fakeDocumentationUseCase.htmlReturns = "example"
                fakeDocumentationUseCase.titleReturns = "title"
                subject.configure(documentation: documentationType)
            }

            it("sets the documentation type") {
                expect(subject.documentation) == documentationType
            }

            it("sets the title to whatever the documentation use case returns for title") {
                expect(subject.title) == "title"
            }

            it("tells the HTMLViewController to load the html that the documentation use case returns for html") {
                expect(htmlViewController.htmlString) == "example"
            }
        }

        describe("the HTMLViewController's delegate") {
            describe("tapping a link") {
                it("opens the link in an SFSafariViewController") {
                    let url = URL(string: "https://example.com")!
                    let shouldOpen = htmlViewController.delegate?.openURL(url: url)
                    expect(shouldOpen) == true
                    expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                }
            }

            context("3d touching a link") {
                describe("3d touching a standard link") {
                    var viewController: UIViewController?

                    beforeEach {
                        viewController = htmlViewController.delegate?.peekURL(url: URL(string: "https://example.com/foo")!)
                    }

                    it("presents another FindFeedViewController configured with that link") {
                        expect(viewController).to(beAnInstanceOf(SFSafariViewController.self))
                    }

                    it("replaces the navigation controller's view controller stack with just that view controller") {
                        guard let viewController = viewController else { fail(); return }
                        htmlViewController.delegate?.commitViewController(viewController: viewController)

                        expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                    }
                }
            }
        }
    }
}

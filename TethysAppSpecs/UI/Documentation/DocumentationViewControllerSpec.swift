import Quick
import Nimble
import UIKit
import SafariServices
import Tethys

class DocumentationViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: DocumentationViewController!
        var documentationUseCase: FakeDocumentationUseCase!
        var htmlViewController: HTMLViewController!
        var themeRepository: ThemeRepository!
        var navigationController: UINavigationController!

        beforeEach {
            documentationUseCase = FakeDocumentationUseCase()
            themeRepository = ThemeRepository(userDefaults: nil)
            htmlViewController = HTMLViewController(themeRepository: themeRepository)

            subject = DocumentationViewController(
                documentationUseCase: documentationUseCase,
                themeRepository: themeRepository,
                htmlViewController: htmlViewController
            )

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
                documentationUseCase.htmlReturns = "example"
                documentationUseCase.titleReturns = "title"
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

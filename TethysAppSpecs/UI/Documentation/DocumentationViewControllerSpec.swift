import Quick
import Nimble
import UIKit
import SafariServices
import Tethys

class DocumentationViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: DocumentationViewController!
        var htmlViewController: HTMLViewController!
        var themeRepository: ThemeRepository!
        var navigationController: UINavigationController!

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)
            htmlViewController = HTMLViewController(themeRepository: themeRepository)
        }

        func expectedDocumentationHtml(documentation: Documentation) -> String {
            let cssURL = Bundle.main.url(forResource: themeRepository.articleCSSFileName, withExtension: "css")!
            let css = try! String(contentsOf: cssURL)

            let expectedPrefix = "<html><head>" +
                "<style type=\"text/css\">\(css)</style>" +
                "<meta name=\"viewport\" content=\"initial-scale=1.0,maximum-scale=10.0\"/>" +
            "</head><body>"

            let expectedPostfix = "</body></html>"

            let resourceName: String
            switch documentation {
            case .libraries:
                resourceName = "libraries"
            case .icons:
                resourceName = "icons"
            }

            let librariesURL = Bundle.main.url(forResource: resourceName, withExtension: "html")!
            let librariesContents = try! String(contentsOf: librariesURL)

            return expectedPrefix + librariesContents + expectedPostfix
        }

        func itBehavesLikeItDisplaysDocumentation(_ documentation: Documentation, expectedTitle: String) {
            it("sets the title based on the documentation") {
                expect(subject.title) == expectedTitle
            }

            it("tells the HTMLViewController to load the html that the documentation use case returns for html") {
                expect(htmlViewController.htmlString) == expectedDocumentationHtml(documentation: documentation)
            }

            describe("changing the theme") {
                beforeEach {
                    themeRepository.theme = .dark
                }

                it("updates the navigation bar") {
                    expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
                    expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
                }

                it("reloads the documentation html") {
                    expect(htmlViewController.htmlString) == expectedDocumentationHtml(documentation: documentation)
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

        describe("when init'd with .libraries") {
            beforeEach {
                subject = DocumentationViewController(
                    documentation: .libraries,
                    themeRepository: themeRepository,
                    htmlViewController: htmlViewController
                )

                navigationController = UINavigationController(rootViewController: subject)

                subject.view.layoutIfNeeded()
            }

            itBehavesLikeItDisplaysDocumentation(.libraries, expectedTitle: "Libraries")
        }

        describe("when init'd with .icons") {
            beforeEach {
                subject = DocumentationViewController(
                    documentation: .icons,
                    themeRepository: themeRepository,
                    htmlViewController: htmlViewController
                )

                navigationController = UINavigationController(rootViewController: subject)

                subject.view.layoutIfNeeded()
            }

            itBehavesLikeItDisplaysDocumentation(.icons, expectedTitle: "Icons")
        }
    }
}

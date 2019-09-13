import Quick
import Nimble
import UIKit
import SafariServices
import Tethys

class DocumentationViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: DocumentationViewController!
        var htmlViewController: HTMLViewController!
        var navigationController: UINavigationController!

        beforeEach {
            htmlViewController = HTMLViewController()
        }

        func expectedDocumentationHtml(documentation: Documentation) -> String {
            let cssURL = Bundle.main.url(forResource: Theme.articleCSSFileName, withExtension: "css")!
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
                    htmlViewController: htmlViewController
                )

                navigationController = UINavigationController(rootViewController: subject)

                subject.view.layoutIfNeeded()
            }

            itBehavesLikeItDisplaysDocumentation(.icons, expectedTitle: "Icons")
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSAttributedStringKeyDictionary(_ input: [NSAttributedString.Key: Any]?) -> [String: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

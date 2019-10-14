import Quick
import Nimble
import TOBrowserActivityKit
import SafariServices
@testable import Tethys
@testable import TethysKit

class ArticleViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ArticleViewController!
        var navigationController: UINavigationController!
        var htmlViewController: HTMLViewController!
        var articleUseCase: FakeArticleUseCase!

        let article = articleFactory(title: "fancy article title")

        beforeEach {
            articleUseCase = FakeArticleUseCase()

            htmlViewController = htmlViewControllerFactory()

            articleUseCase.readArticleReturns("example")

            subject = ArticleViewController(
                article: article,
                articleUseCase: articleUseCase,
                htmlViewController: { htmlViewController }
            )

            navigationController = UINavigationController(rootViewController: subject)

            subject.view.layoutIfNeeded()
        }

        describe("when the view appears") {
            beforeEach {
                subject.viewDidAppear(false)
            }

            it("hides the nav and toolbars on swipe/tap") {
                expect(navigationController.hidesBarsOnSwipe).to(beTruthy())
                expect(navigationController.hidesBarsOnTap).to(beTruthy())
            }

            it("disables hiding the nav and toolbars on swipe/tap when the view disappears") {
                subject.viewWillDisappear(false)
                expect(navigationController.hidesBarsOnSwipe).to(beFalsy())
                expect(navigationController.hidesBarsOnTap).to(beFalsy())
            }
        }

        describe("theming") {
            it("sets the view's background color") {
                expect(subject.view.backgroundColor).to(equal(Theme.backgroundColor))
            }
        }

        describe("Key Commands") {
            it("can become first responder") {
                expect(subject.canBecomeFirstResponder) == true
            }

            func hasKindsOfKeyCommands(expectedCommands: [(input: String, modifierFlags: UIKeyModifierFlags)], discoveryTitles: [String]) {
                let keyCommands = subject.keyCommands
                expect(keyCommands).toNot(beNil())
                guard let commands = keyCommands else {
                    return
                }

                expect(commands.count).to(equal(expectedCommands.count))
                for (idx, cmd) in commands.enumerated() {
                    let expectedCmd = expectedCommands[idx]
                    expect(cmd.input).to(equal(expectedCmd.input))
                    expect(cmd.modifierFlags).to(equal(expectedCmd.modifierFlags))

                    let expectedTitle = discoveryTitles[idx]
                    expect(cmd.discoverabilityTitle).to(equal(expectedTitle))
                }
            }

            it("should not list the next/previous article commands") {
                let expectedCommands = [
                    (input: "r", modifierFlags: UIKeyModifierFlags.shift),
                    (input: "l", modifierFlags: UIKeyModifierFlags.command),
                    (input: "s", modifierFlags: UIKeyModifierFlags.command),
                ]
                let expectedDiscoverabilityTitles = [
                    "Toggle Read",
                    "Open Article in WebView",
                    "Open Share Sheet",
                ]

                hasKindsOfKeyCommands(expectedCommands: expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
            }
        }

        describe("the content") {
            it("asks the use case for the html to show") {
                expect(articleUseCase.readArticleCallCount) == 1
                expect(articleUseCase.readArticleArgsForCall(0)) == article
            }

            it("includes the share button in the toolbar, and the open in safari button") {
                expect(subject.toolbarItems).to(contain(subject.shareButton))
                expect(subject.toolbarItems).to(contain(subject.openInSafariButton))
            }

            it("shows the content") {
                expect(htmlViewController.htmlString).to(contain("example"))
            }

            describe("the share button") {
                it("is configured for accessibility") {
                    expect(subject.shareButton.isAccessibilityElement).to(beTrue())
                    expect(subject.shareButton.accessibilityTraits).to(equal([.button]))
                    expect(subject.shareButton.accessibilityLabel).to(equal("Share fancy article title"))
                }

                describe("tapping it") {
                    beforeEach {
                        subject.shareButton.tap()
                    }

                    it("brings up an activity view controller") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UIActivityViewController.self))
                        if let shareSheet = subject.presentedViewController as? UIActivityViewController {
                            expect(shareSheet.activityItems.count).to(equal(1))
                            expect(shareSheet.activityItems.first as? URL).to(equal(article.link))

                            expect(shareSheet.applicationActivities as? [NSObject]).toNot(beNil())
                            if let activities = shareSheet.applicationActivities as? [NSObject] {
                                expect(activities.first).to(beAnInstanceOf(TOActivitySafari.self))
                                expect(activities.last).to(beAnInstanceOf(TOActivityChrome.self))
                            }
                        }
                    }
                }
            }

            describe("the open link button") {
                it("informs the user what it does") {
                    expect(subject.openInSafariButton.title).to(equal("View URL"))
                }

                it("is configured for accessibility") {
                    expect(subject.openInSafariButton.isAccessibilityElement).to(beTrue())
                    expect(subject.openInSafariButton.accessibilityTraits).to(equal([.button]))
                    expect(subject.openInSafariButton.accessibilityLabel).to(equal("View article URL"))
                }

                describe("when tapped") {
                    beforeEach {
                        subject.openInSafariButton.tap()
                    }

                    it("opens the article in an SFSafariViewController") {
                        expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                    }
                }
            }

            context("tapping a link") {
                it("opens in an SFSafariViewController") {
                    let url = URL(string: "https://example.com")!
                    expect(htmlViewController.delegate?.openURL(url: url)).to(beTrue())
                    expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                }

                it("non-http/https links don't open in SFSafariViewController") {
                    let url = URL(string: "about:none")!

                    expect(htmlViewController.delegate?.openURL(url: url)).to(beFalse())
                    expect(navigationController.visibleViewController).to(be(subject))
                }
            }

            context("HTMLViewControllerDelegate.peekURL") {
                describe("for a standard link") {
                    var viewController: UIViewController?

                    beforeEach {
                        viewController = htmlViewController.delegate?.peekURL(url: URL(string: "https://example.com/foo")!)
                    }

                    it("returns an SFSafariViewController") {
                        expect(viewController).to(beAnInstanceOf(SFSafariViewController.self))
                        guard let safariController = viewController as? SFSafariViewController else { return }
                        expect(safariController.preferredControlTintColor).to(equal(Theme.highlightColor))
                    }

                    it("replaces the navigation controller's view controller stack with just that view controller") {
                        let viewController = UIViewController()
                        htmlViewController.delegate?.commitViewController(viewController: viewController)

                        expect(navigationController.visibleViewController).to(be(viewController))
                    }
                }
            }
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

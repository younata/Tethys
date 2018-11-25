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
        var themeRepository: ThemeRepository!
        var htmlViewController: HTMLViewController!
        var articleUseCase: FakeArticleUseCase!

        let article = articleFactory()

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)
            articleUseCase = FakeArticleUseCase()

            htmlViewController = htmlViewControllerFactory()

            articleUseCase.readArticleReturns("example")

            subject = ArticleViewController(
                article: article,
                themeRepository: themeRepository,
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

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should update the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
            }
            it("should update the toolbar") {
                expect(subject.navigationController?.toolbar.barStyle) == themeRepository.barStyle
            }
        }

        describe("Key Commands") {
            it("can become first responder") {
                expect(subject.canBecomeFirstResponder) == true
            }

            func hasKindsOfKeyCommands(expectedCommands: [UIKeyCommand], discoveryTitles: [String]) {
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
                    UIKeyCommand(input: "r", modifierFlags: .shift, action: #selector(BlankTarget.blank)),
                    UIKeyCommand(input: "l", modifierFlags: .command, action: #selector(BlankTarget.blank)),
                    UIKeyCommand(input: "s", modifierFlags: .command, action: #selector(BlankTarget.blank)),
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
                expect(subject.toolbarItems?.contains(subject.shareButton)) == true
                expect(subject.toolbarItems?.contains(subject.openInSafariButton)) == true
            }

            it("shows the content") {
                expect(htmlViewController.htmlString).to(contain("example"))
            }

            describe("tapping the share button") {
                beforeEach {
                    subject.shareButton.tap()
                }

                it("should bring up an activity view controller") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(URLShareSheet.self))
                    if let activityViewController = subject.presentedViewController as? URLShareSheet {
                        expect(activityViewController.activityItems.count) == 1
                        expect(activityViewController.activityItems.first as? URL) == article.link
                        expect(activityViewController.url) == article.link
                        expect(activityViewController.themeRepository) == themeRepository

                        expect(activityViewController.applicationActivities as? [NSObject]).toNot(beNil())
                        if let activities = activityViewController.applicationActivities as? [NSObject] {
                            expect(activities.first).to(beAnInstanceOf(TOActivitySafari.self))
                            expect(activities.last).to(beAnInstanceOf(TOActivityChrome.self))
                        }
                    }
                }
            }
            
            it("should open the article in an SFSafariViewController if the open in safari button is tapped") {
                subject.openInSafariButton.tap()

                expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
            }

            context("tapping a link") {
                it("opens in an SFSafariViewController") {
                    let url = URL(string: "https://example.com")!
                    let shouldOpen = htmlViewController.delegate?.openURL(url: url)
                    expect(shouldOpen) == true
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

                    it("presents an SFSafariViewController configured with that link") {
                        expect(viewController).to(beAnInstanceOf(SFSafariViewController.self))
                    }

                    it("replaces the navigation controller's view controller stack with just that view controller") {
                        htmlViewController.delegate?.commitViewController(viewController: viewController!)

                        expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                    }
                }
            }
        }
    }
}

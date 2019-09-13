import Quick
import Nimble
import Tethys

class FakeHTMLViewControllerDelegate: HTMLViewControllerDelegate {
    var openURLReturns = false
    var openURLArgs: [URL] = []
    func openURL(url: URL) -> Bool {
        openURLArgs.append(url)
        return openURLReturns
    }

    var peekURLReturns: UIViewController?
    var peekURLArgs: [URL] = []
    func peekURL(url: URL) -> UIViewController? {
        peekURLArgs.append(url)
        return peekURLReturns
    }

    var commitViewControllerArgs: [UIViewController] = []
    func commitViewController(viewController: UIViewController) {
        commitViewControllerArgs.append(viewController)
    }
}

class HTMLViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: HTMLViewController!

        beforeEach {
            subject = HTMLViewController()

            expect(subject.view).toNot(beNil())
        }

        describe("the theme") {
            it("sets the content's background color") {
                expect(subject.content.backgroundColor).to(equal(Theme.backgroundColor))
            }

            it("sets the progress view's colors") {
                expect(subject.progressIndicator.trackTintColor).to(equal(Theme.progressTrackColor))
                expect(subject.progressIndicator.progressTintColor).to(equal(Theme.progressTintColor))
            }
        }

        it("has link preview with 3d touch enabled") {
            expect(subject.content.allowsLinkPreview) == true
        }

        it("does not show the progress indicator") {
            expect(subject.progressIndicator.isHidden) == true
        }

        describe("setting the html text") {
            beforeEach {
                subject.configure(html: "<html><body></body></html>")
            }

            it("shows the progress indicator") {
                expect(subject.progressIndicator.isHidden) == false
            }

            describe("when the article loads") {
                beforeEach {
                    subject.content.navigationDelegate?.webView?(subject.content, didFinish: nil)
                }

                it("hides the progressIndicator") {
                    expect(subject.progressIndicator.isHidden) == true
                }
            }

            context("tapping a link") {
                let url = URL(string: "https://example.com/")!
                var shouldInteract: Bool?
                var delegate: FakeHTMLViewControllerDelegate!
                beforeEach {
                    shouldInteract = false
                    delegate = FakeHTMLViewControllerDelegate()
                }

                it("asks it's delegate what to do and returns .cancel if the delegate wants to open the url itself") {
                    subject.delegate = delegate
                    delegate.openURLReturns = true
                    let navAction = FakeWKNavigationAction(url: url, navigationType: .linkActivated)
                    subject.content.navigationDelegate?.webView?(subject.content, decidePolicyFor: navAction) { (actionPolicy: WKNavigationActionPolicy) -> Void in
                        shouldInteract = (actionPolicy == WKNavigationActionPolicy.allow)
                    }
                    expect(shouldInteract) == false
                }

                it("asks it's delegate what to do and returns .allow if the delegate doesn't want to open the url") {
                    subject.delegate = delegate
                    delegate.openURLReturns = false
                    let navAction = FakeWKNavigationAction(url: url, navigationType: .linkActivated)
                    subject.content.navigationDelegate?.webView?(subject.content, decidePolicyFor: navAction) { (actionPolicy: WKNavigationActionPolicy) -> Void in
                        shouldInteract = (actionPolicy == WKNavigationActionPolicy.allow)
                    }
                    expect(shouldInteract) == true
                }

                it("asks it's delegate what to do and returns .allow if the delegate is nil") {
                    let url = URL(string: "https://example.com")!
                    subject.delegate = nil
                    let navAction = FakeWKNavigationAction(url: url, navigationType: .linkActivated)
                    subject.content.navigationDelegate?.webView?(subject.content, decidePolicyFor: navAction) { (actionPolicy: WKNavigationActionPolicy) -> Void in
                        shouldInteract = (actionPolicy == WKNavigationActionPolicy.allow)
                    }
                    expect(shouldInteract) == true
                }
            }

            context("3d touching a link") {
                var receivedViewController: UIViewController?
                let element = FakeWKPreviewItem(link: URL(string: "https://example.com/foo"))
                let viewController = UIViewController()
                var delegate: FakeHTMLViewControllerDelegate!

                beforeEach {
                    delegate = FakeHTMLViewControllerDelegate()
                    subject.delegate = delegate
                    delegate.peekURLReturns = viewController
                    receivedViewController = subject.content.uiDelegate?.webView?(subject.content,
                                                                          previewingViewControllerForElement: element,
                                                                          defaultActions: [])
                }

                it("returns whatever the delegate says") {
                    expect(delegate.peekURLArgs.last) == URL(string: "https://example.com/foo")!
                    expect(receivedViewController).to(beIdenticalTo(viewController))
                }

                it("replaces the navigation controller's view controller stack with just that view controller") {
                    subject.content.uiDelegate?.webView?(subject.content,
                                                         commitPreviewingViewController: receivedViewController!)

                    expect(delegate.commitViewControllerArgs.last) == receivedViewController
                }
            }
        }
    }
}

import Quick
import Nimble
import Tethys
import SafariServices

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

            describe("link context menus") {
                let element = FakeWKContentMenuElementInfo.new(linkURL: URL(string: "https://example.com/foo")!)
                var delegate: FakeHTMLViewControllerDelegate!
                var contextMenuCalls: [UIContextMenuConfiguration?] = []

                var viewController: UIViewController!

                beforeEach {
                    delegate = FakeHTMLViewControllerDelegate()
                    subject.delegate = delegate

                    contextMenuCalls = []
                }

                context("if delegate.peekURL returns nil") {
                    beforeEach {
                        viewController = UIViewController()
                        delegate.peekURLReturns = nil
                        subject.content.uiDelegate?.webView?(
                            subject.content,
                            contextMenuConfigurationForElement: element,
                            completionHandler: { contextMenuCalls.append($0) }
                        )
                    }

                    it("calls the callback with nil") {
                        expect(delegate.peekURLArgs.last).to(equal(URL(string: "https://example.com/foo")!))
                        expect(contextMenuCalls).to(haveCount(1))
                        expect(contextMenuCalls.last!).to(beNil())
                    }

                    it("replaces the navigation controller's view controller stack with just that view controller") {
                        let animator = FakeContextMenuAnimator(commitStyle: .pop, viewController: viewController)

                        subject.content.uiDelegate?.webView?(
                            subject.content,
                            contextMenuForElement: element,
                            willCommitWithAnimator: animator
                        )

                        expect(animator.addAnimationsCalls).to(beEmpty())
                        expect(animator.addCompletionCalls).to(haveCount(1))
                        animator.addCompletionCalls.last?()
                        expect(delegate.commitViewControllerArgs.last).to(equal(viewController))
                    }
                }

                context("if delegate.peekURL returns a different kind of view controller") {
                    beforeEach {
                        viewController = UIViewController()
                        delegate.peekURLReturns = viewController
                        subject.content.uiDelegate?.webView?(
                            subject.content,
                            contextMenuConfigurationForElement: element,
                            completionHandler: { contextMenuCalls.append($0) }
                        )
                    }

                    it("returns context menu configured to show the view controller") {
                        expect(delegate.peekURLArgs.last).to(equal(URL(string: "https://example.com/foo")))
                        expect(contextMenuCalls).to(haveCount(1))
                        guard let contextMenu = contextMenuCalls.last else {
                            return expect(contextMenuCalls.last).toNot(beNil())
                        }
                        expect(contextMenu?.identifier as? NSURL).to(equal(URL(string: "https://example.com/foo")! as NSURL))
                        expect(contextMenu?.previewProvider?()).to(equal(viewController))
                    }

                    it("replaces the navigation controller's view controller stack with just that view controller") {
                        let animator = FakeContextMenuAnimator(commitStyle: .pop, viewController: viewController)

                        subject.content.uiDelegate?.webView?(
                            subject.content,
                            contextMenuForElement: element,
                            willCommitWithAnimator: animator
                        )

                        expect(animator.addAnimationsCalls).to(beEmpty())
                        expect(animator.addCompletionCalls).to(haveCount(1))
                        animator.addCompletionCalls.last?()
                        expect(delegate.commitViewControllerArgs.last).to(equal(viewController))
                    }
                }
            }
        }
    }
}

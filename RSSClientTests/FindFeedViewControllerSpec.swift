import Quick
import Nimble
import Ra
import rNews

class FindFeedViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FindFeedViewController! = nil

        var navController : UINavigationController! = nil

        var injector : Ra.Injector! = nil

        beforeEach {
            injector = Ra.Injector(module: SpecInjectorModule())
            subject = injector.create(FindFeedViewController.self) as! FindFeedViewController

            navController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("Looking up feeds on the interwebs") {
            it("should auto-prepend 'https://' if it's not already there") {
                subject.navField.text = "example.com"
                subject.textFieldShouldReturn(subject.navField)
                expect(subject.navField.text).to(equal("http://example.com"))
            }
        }

        describe("WKWebView and Delegates") {
            beforeEach {
                subject.webView(subject.webContent, didStartProvisionalNavigation: nil)
            }

            it("should show the loadingBar") {
                expect(subject.loadingBar.hidden).to(beFalsy())
                expect(subject.loadingBar.progress).to(beCloseTo(0))
            }

            it("should disable the addFeedButton") {
                expect(subject.addFeedButton.enabled).to(beFalsy())
            }

            describe("Failing to load the page") {
                context("before loading the page (network error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailProvisionalNavigation: nil, withError: NSError())
                    }

                    it("should hide the webview") {
                        expect(subject.loadingBar.hidden).to(beTruthy())
                    }
                }

                context("trying to load the content (html rendering error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailNavigation: nil, withError: NSError())
                    }

                    it("should hide the webview") {
                        expect(subject.loadingBar.hidden).to(beTruthy())
                    }
                }
            }

            describe("successfully loading a page") {
                beforeEach {
                    subject.webView(subject.webContent, didFinishNavigation: nil)
                }

                it("should hide the loadingBar") {
                    expect(subject.loadingBar.hidden).to(beTruthy())
                }

                it("should allow the user to reload the page") {
                    expect(subject.navigationItem.rightBarButtonItem).to(equal(subject.reload))
                }
            }
        }
    }
}

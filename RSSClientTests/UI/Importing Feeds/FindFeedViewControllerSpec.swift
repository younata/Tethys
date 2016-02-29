import Quick
import Nimble
import Ra
import rNews
import rNewsKit

private var navController: UINavigationController! = nil
private var feedRepository: FakeFeedRepository! = nil
private var rootViewController: UIViewController! = nil


class FindFeedViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FindFeedViewController!

        var injector: Ra.Injector!
        var webView: FakeWebView!
        var importUseCase: FakeImportUseCase!
        var opmlService: FakeOPMLService!
        var themeRepository: FakeThemeRepository!

        beforeEach {
            injector = Ra.Injector()

            feedRepository = FakeFeedRepository()
            injector.bind(FeedRepository.self, toInstance: feedRepository)

            importUseCase = FakeImportUseCase()
            injector.bind(ImportUseCase.self, toInstance: importUseCase)

            opmlService = FakeOPMLService()
            injector.bind(OPMLService.self, toInstance: opmlService)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(FindFeedViewController)!
            webView = FakeWebView()
            subject.webContent = webView

            navController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should update the navigation bar background") {
                expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
            }

            it("should update the toolbar") {
                expect(subject.navigationController?.toolbar.barStyle) == themeRepository.barStyle
            }

            it("should update the webView's background color") {
                expect(subject.webContent.backgroundColor) == themeRepository.backgroundColor
            }

            it("should update the scroll indicator style") {
                expect(subject.webContent.scrollView.indicatorStyle) == themeRepository.scrollIndicatorStyle
            }
        }

        describe("Looking up feeds on the interwebs") {
            beforeEach {
                subject.navField.text = "example.com"
                subject.textFieldShouldReturn(subject.navField)
            }

            it("should auto-prepend 'http://' if it's not already there") {
                expect(subject.navField.text) == "http://example.com"
            }

            it("should navigate the webview that url") {
                expect(webView.lastRequestLoaded?.URL) == NSURL(string: "http://example.com")
            }
        }

        describe("key commands") {
            it("can become first responder") {
                expect(subject.canBecomeFirstResponder()) == true
            }

            it("has 2 key commands initially") {
                expect(subject.keyCommands?.count) == 2
            }

            describe("the first command") {
                it("is bound to cmd+l") {
                    guard let keyCommand = subject.keyCommands?.first else { fail("precondition failed"); return }

                    expect(keyCommand.input) == "l"
                }

                if #available(iOS 9, *) {
                    it("is titled 'open URL'") {
                        guard let keyCommand = subject.keyCommands?.first else { fail("precondition failed"); return }

                        expect(keyCommand.discoverabilityTitle) == "Open URL"
                    }
                }
            }

            describe("the second command") {
                it("is bound to cmd+r") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                    expect(keyCommand.input) == "r"
                }

                if #available(iOS 9, *) {
                    it("is titled 'Reload'") {
                        guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                        expect(keyCommand.discoverabilityTitle) == "Reload"
                    }
                }
            }

            context("when a feed is detected in a web page") {
                let url = NSURL(string: "https://example.com/feed")!
                let feedURL = NSURL(string: "https://example.com/feed1")!

                beforeEach {
                    webView.fakeUrl = url
                    subject.webView(subject.webContent, didStartProvisionalNavigation: nil)

                    importUseCase.scanForImportableArgsForCall(0).1(.WebPage(url, [feedURL]))
                }

                it("adds a third command") {
                    expect(subject.keyCommands?.count) == 3
                }

                it("is bound to cmd+i") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                    expect(keyCommand.input) == "i"
                }

                if #available(iOS 9, *) {
                    it("is titled 'Import'") {
                        guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                        expect(keyCommand.discoverabilityTitle) == "Import"
                    }
                }
            }
        }

        describe("WKWebView and Delegates") {
            beforeEach {
                webView.fakeUrl = NSURL(string: "https://example.com/feed.xml")
                subject.webView(subject.webContent, didStartProvisionalNavigation: nil)
            }

            let showRootController: (Void) -> (Void) = {
                rootViewController = UIViewController()

                rootViewController.presentViewController(navController, animated: false, completion: nil)
                expect(rootViewController.presentedViewController).toNot(beNil())
            }

            sharedExamples("importing a feed") { (sharedContext: SharedExampleContext) in
                var url: NSURL!

                beforeEach {
                    url = (sharedContext()["url"] as? NSURL) ?? NSURL(string: "https://example.com/feed")!
                }

                it("asks the import use case to import the feed at the url") {
                    expect(importUseCase.importItemArgsForCall(0).0) == url
                }

                it("should show an indicator that we're doing things") {
                    let indicator = subject.view.subviews.filter {
                        return $0.isKindOfClass(ActivityIndicator.classForCoder())
                        }.first as? ActivityIndicator
                    expect(indicator?.message) == "Loading feed at \(url.absoluteString)"
                }

                describe("when the use case is finished") {
                    beforeEach {
                        importUseCase.importItemArgsForCall(0).1()
                    }

                    it("should remove the indicator") {
                        let indicator = navController.view.subviews.filter {
                            return $0.isKindOfClass(ActivityIndicator.classForCoder())
                            }.first
                        expect(indicator).to(beNil())
                    }

                    it("should dismiss itself") {
                        expect(rootViewController.presentedViewController).to(beNil())
                    }
                }
            }

            it("should show the loadingBar") {
                expect(subject.loadingBar.hidden) == false
                expect(subject.loadingBar.progress).to(beCloseTo(0))
            }

            it("should disable the addFeedButton") {
                expect(subject.addFeedButton.enabled) == false
            }

            describe("tapping the navField") {
                beforeEach {
                    subject.navField.delegate?.textFieldDidBeginEditing?(subject.navField)
                }

                it("fills the navField's text with the webView's url") {
                    expect(subject.navField.text) == "https://example.com/feed.xml"
                }

                it("goes back to the webView's title when loaded cancel is tapped") {
                    subject.cancelTextEntry.tap()

                    expect(subject.navField.text) == ""
                }
            }

            it("asks the import use case to check if the page at the url has a feed") {
                expect(importUseCase.scanForImportableArgsForCall(0).0) == NSURL(string: "https://example.com/feed.xml")
            }

            context("when the use case finds a feed") {
                let url = NSURL(string: "https://example.com/feed")!
                beforeEach {
                    showRootController()
                    importUseCase.scanForImportableArgsForCall(0).1(.Feed(url, 0))
                }

                it("should present an alert") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                    if let alert = subject.presentedViewController as? UIAlertController {
                        expect(alert.title) == "Feed Detected"
                        expect(alert.message) == "Import feed?"

                        expect(alert.actions.count) == 2
                        if let dontsave = alert.actions.first {
                            expect(dontsave.title) == "Don't Import"
                        }
                        if let save = alert.actions.last {
                            expect(save.title) == "Import"
                        }
                    }
                }

                describe("tapping 'Don't Import'") {
                    beforeEach {
                        if let alert = subject.presentedViewController as? UIAlertController,
                            let action = alert.actions.first {
                                action.handler()(action)
                        }
                    }

                    it("should dismiss the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }
                }

                describe("tapping 'Import'") {
                    beforeEach {
                        if let alert = subject.presentedViewController as? UIAlertController,
                            let action = alert.actions.last {
                                action.handler()(action)
                        }
                    }

                    it("should dismiss the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }

                    itBehavesLike("importing a feed")
                }
            }

            context("when the use case finds an opml file") {
                let url = NSURL(string: "https://example.com/feed")!
                beforeEach {
                    showRootController()
                    importUseCase.scanForImportableArgsForCall(0).1(.OPML(url, 0))
                }

                it("should present an alert") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                    if let alert = subject.presentedViewController as? UIAlertController {
                        expect(alert.title) == "Feed List Detected"
                        expect(alert.message) == "Import?"

                        expect(alert.actions.count) == 2
                        if let dontsave = alert.actions.first {
                            expect(dontsave.title) == "Don't Import"
                        }
                        if let save = alert.actions.last {
                            expect(save.title) == "Import"
                        }
                    }
                }

                describe("tapping 'Don't Import'") {
                    beforeEach {
                        if let alert = subject.presentedViewController as? UIAlertController,
                            let action = alert.actions.first {
                                action.handler()(action)
                        }
                    }

                    it("should dismiss the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }
                }

                describe("tapping 'Import'") {
                    beforeEach {
                        if let alert = subject.presentedViewController as? UIAlertController,
                            let action = alert.actions.last {
                                action.handler()(action)
                        }
                    }

                    it("should dismiss the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }

                    it("should show an indicator that we're doing things") {
                        let indicator = subject.view.subviews.filter {
                            return $0.isKindOfClass(ActivityIndicator.classForCoder())
                        }.first as? ActivityIndicator
                        expect(indicator?.message) == "Loading feed list at https://example.com/feed"
                    }

                    it("asks the import use case to import the feed at the url") {
                        expect(importUseCase.importItemArgsForCall(0).0) == url
                    }

                    describe("when the use case is finished") {
                        beforeEach {
                            importUseCase.importItemArgsForCall(0).1()
                        }

                        it("should remove the indicator") {
                            let indicator = subject.view.subviews.filter {
                                return $0.isKindOfClass(ActivityIndicator.classForCoder())
                                }.first
                            expect(indicator).to(beNil())
                        }

                        it("should dismiss itself") {
                            expect(rootViewController.presentedViewController).to(beNil())
                        }
                    }
                }
            }

            context("when the use case finds a web page with a single feed") {
                let url = NSURL(string: "https://example.com/feed")!
                let feedURL = NSURL(string: "https://example.com/feed1")!

                beforeEach {
                    importUseCase.scanForImportableArgsForCall(0).1(.WebPage(url, [feedURL]))
                }

                it("should enable the addFeedButton") {
                    expect(subject.addFeedButton.enabled) == true
                }

                describe("tapping on the addFeedButton") {
                    beforeEach {
                        showRootController()
                        subject.addFeedButton.tap()
                    }

                    itBehavesLike("importing a feed") {
                        return ["url": feedURL]
                    }
                }
            }

            context("when the use case finds a web page with multiple feeds") {
                let url = NSURL(string: "https://example.com/feed")!
                let feedURL1 = NSURL(string: "https://example.com/feed1")!
                let feedURL2 = NSURL(string: "https://example.com/feed2")!

                beforeEach {
                    importUseCase.scanForImportableArgsForCall(0).1(.WebPage(url, [feedURL1, feedURL2]))
                }

                it("should enable the addFeedButton") {
                    expect(subject.addFeedButton.enabled) == true
                }

                describe("tapping on the addFeedButton") {
                    beforeEach {
                        showRootController()
                        subject.addFeedButton.tap()
                    }

                    it("should bring up a list of available feeds to import") {
                        expect(subject.presentedViewController).to(beAKindOf(UIAlertController.self))
                        if let alertController = subject.presentedViewController as? UIAlertController {
                            expect(alertController.actions.count) == 3

                            guard alertController.actions.count == 3 else { return }

                            let firstAction = alertController.actions[0]
                            expect(firstAction.title) == "feed1"

                            let secondAction = alertController.actions[1]
                            expect(secondAction.title) == "feed2"

                            let thirdAction = alertController.actions[2]
                            expect(thirdAction.title) == "Cancel"
                        }
                    }

                    context("tapping on one of the feed actions") {
                        beforeEach {
                            let actions = (subject.presentedViewController as? UIAlertController)?.actions ?? []
                            if actions.count == 3 {
                                let action = actions[1]
                                action.handler()(action)
                            } else {
                                fail("precondition failed")
                            }
                        }

                        itBehavesLike("importing a feed") {
                            return ["url": feedURL2]
                        }
                    }
                }
            }

            context("when the use case finds a web page with no feeds") {
                let url = NSURL(string: "https://example.com/feed")!
                beforeEach {
                    importUseCase.scanForImportableArgsForCall(0).1(.WebPage(url, []))
                }

                it("should do nothing") {
                    expect(subject.presentedViewController).to(beNil())
                }
            }

            context("when the use case finds nothing") {
                let url = NSURL(string: "https://example.com/feed")!
                beforeEach {
                    importUseCase.scanForImportableArgsForCall(0).1(.None(url))
                }

                it("should do nothing") {
                    expect(subject.presentedViewController).to(beNil())
                }
            }

            describe("Failing to load the page") {
                let err = NSError(domain: "", code: 0, userInfo: [:])
                context("before loading the page (network error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailProvisionalNavigation: nil, withError: err)
                    }

                    it("should hide the webview") {
                        expect(subject.loadingBar.hidden) == true
                    }
                }

                context("trying to load the content (html rendering error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailNavigation: nil, withError: err)
                    }

                    it("should hide the webview") {
                        expect(subject.loadingBar.hidden) == true
                    }
                }
            }

            describe("successfully loading a page") {
                beforeEach {
                    subject.webView(subject.webContent, didFinishNavigation: nil)
                }

                it("should hide the loadingBar") {
                    expect(subject.loadingBar.hidden) == true
                }

                it("should allow the user to reload the page") {
                    expect(subject.navigationItem.rightBarButtonItem) == subject.reload
                }
            }
        }
    }
}

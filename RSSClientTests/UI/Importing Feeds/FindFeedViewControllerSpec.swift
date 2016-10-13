import Quick
import Nimble
import Ra
import rNews
import rNewsKit
import SafariServices

private var navController: UINavigationController! = nil
private var feedRepository: FakeDatabaseUseCase! = nil
private var rootViewController: UIViewController! = nil


class FindFeedViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FindFeedViewController!

        var injector: Ra.Injector!
        var webView: FakeWebView!
        var importUseCase: FakeImportUseCase!
        var opmlService: FakeOPMLService!
        var themeRepository: ThemeRepository!
        var analytics: FakeAnalytics!

        beforeEach {
            injector = Ra.Injector()

            feedRepository = FakeDatabaseUseCase()
            injector.bind(kind: DatabaseUseCase.self, toInstance: feedRepository)

            importUseCase = FakeImportUseCase()
            injector.bind(kind: ImportUseCase.self, toInstance: importUseCase)

            opmlService = FakeOPMLService()
            injector.bind(kind: OPMLService.self, toInstance: opmlService)

            analytics = FakeAnalytics()
            injector.bind(kind: Analytics.self, toInstance: analytics)

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            subject = injector.create(kind: FindFeedViewController.self)!
            webView = FakeWebView()
            subject.webContent = webView

            navController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
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

        it("tells analytics to log that the user viewed WebImport") {
            expect(analytics.logEventCallCount) == 1
            if (analytics.logEventCallCount > 0) {
                expect(analytics.logEventArgsForCall(0).0) == "DidViewWebImport"
                expect(analytics.logEventArgsForCall(0).1).to(beNil())
            }
        }

        describe("Looking up feeds on the interwebs") {
            beforeEach {
                subject.navField.text = "example.com"
                _ = subject.textFieldShouldReturn(subject.navField)
            }

            it("should auto-prepend 'https://' if it's not already there") {
                expect(subject.navField.text) == "https://example.com"
            }

            it("should navigate the webview that url") {
                expect(webView.lastRequestLoaded?.url) == URL(string: "https://example.com")
            }
        }

        describe("Entering an invalid url") {
            it("searches duckduckgo for that text when given a string with a single word") {
                subject.navField.text = "notaurl"
                _ = subject.textFieldShouldReturn(subject.navField)
                expect(webView.lastRequestLoaded?.url) == URL(string: "https://duckduckgo.com/?q=notaurl")
            }

            it("searches duckduckgo for that text when given a string with multiple words") {
                subject.navField.text = "not a url"
                _ = subject.textFieldShouldReturn(subject.navField)
                expect(webView.lastRequestLoaded?.url) == URL(string: "https://duckduckgo.com/?q=not+a+url")
            }
        }

        describe("key commands") {
            it("can become first responder") {
                expect(subject.canBecomeFirstResponder) == true
            }

            it("has 2 key commands initially") {
                expect(subject.keyCommands?.count) == 2
            }

            describe("the first command") {
                it("is bound to cmd+l") {
                    guard let keyCommand = subject.keyCommands?.first else { fail("precondition failed"); return }

                    expect(keyCommand.input) == "l"
                }

                it("is titled 'open URL'") {
                    guard let keyCommand = subject.keyCommands?.first else { fail("precondition failed"); return }

                    expect(keyCommand.discoverabilityTitle) == "Open URL"
                }
            }

            describe("the second command") {
                it("is bound to cmd+r") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                    expect(keyCommand.input) == "r"
                }

                it("is titled 'Reload'") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                    expect(keyCommand.discoverabilityTitle) == "Reload"
                }
            }

            context("when a feed is detected in a web page") {
                let url = URL(string: "https://example.com/feed")!
                let feedURL = URL(string: "https://example.com/feed1")!

                beforeEach {
                    webView.fakeUrl = url
                    subject.webView(subject.webContent, didStartProvisionalNavigation: nil)

                    importUseCase.scanForImportablePromises[0].resolve(.webPage(url, [feedURL]))
                }

                it("adds a third command") {
                    expect(subject.keyCommands?.count) == 3
                }

                it("is bound to cmd+i") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                    expect(keyCommand.input) == "i"
                }

                it("is titled 'Import'") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                    expect(keyCommand.discoverabilityTitle) == "Import"
                }
            }
        }

        describe("WKWebView and Delegates") {
            beforeEach {
                webView.fakeUrl = URL(string: "https://example.com/feed.xml")
                subject.webView(subject.webContent, didStartProvisionalNavigation: nil)
            }

            let showRootController: (Void) -> (Void) = {
                rootViewController = UIViewController()

                rootViewController.present(navController, animated: false, completion: nil)
                expect(rootViewController.presentedViewController).toNot(beNil())
            }

            sharedExamples("importing a feed") { (sharedContext: @escaping SharedExampleContext) in
                var url: URL!

                beforeEach {
                    url = (sharedContext()["url"] as? URL) ?? URL(string: "https://example.com/feed")!
                }

                it("asks the import use case to import the feed at the url") {
                    expect(importUseCase.importItemArgsForCall(callIndex: 0)) == url
                }

                it("should show an indicator that we're doing things") {
                    let indicator = subject.view.subviews.filter {
                        return $0.isKind(of: ActivityIndicator.classForCoder())
                        }.first as? ActivityIndicator
                    expect(indicator?.message) == "Loading feed at \(url.absoluteString)"
                }

                describe("when the use case is finished") {
                    beforeEach {
                        importUseCase.importItemPromises[0].resolve(.success())
                    }

                    it("should remove the indicator") {
                        let indicator = navController.view.subviews.filter {
                            return $0.isKind(of: ActivityIndicator.classForCoder())
                            }.first
                        expect(indicator).to(beNil())
                    }

                    it("tells analytics to log that the user used WebImport") {
                        expect(analytics.logEventCallCount) == 2
                        if (analytics.logEventCallCount > 1) {
                            expect(analytics.logEventArgsForCall(1).0) == "DidUseWebImport"
                            expect(analytics.logEventArgsForCall(1).1).to(beNil())
                        }
                    }

                    it("should dismiss itself") {
                        expect(rootViewController.presentedViewController).to(beNil())
                    }
                }
            }

            it("should show the loadingBar") {
                expect(subject.loadingBar.isHidden) == false
                expect(subject.loadingBar.progress).to(beCloseTo(0))
            }

            it("should disable the addFeedButton") {
                expect(subject.addFeedButton.isEnabled) == false
            }

            describe("3d touch events") {
                describe("when the user tries to peek on a link") {
                    var viewController: UIViewController?
                    let element = FakeWKPreviewItem(link: URL(string: "https://example.com/foo"))

                    beforeEach {
                        viewController = subject.webContent.uiDelegate?.webView?(subject.webContent,
                                                                                 previewingViewControllerForElement: element,
                                                                                 defaultActions: [])
                    }

                    it("presents another FindFeedViewController configured with that link") {
                        expect(viewController).to(beAnInstanceOf(FindFeedViewController.self))
                        expect(viewController).toNot(equal(subject))
                    }

                    it("replaces the navigation controller's view controller stack with just that view controller") {
                        subject.webContent.uiDelegate?.webView?(subject.webContent,
                                                                commitPreviewingViewController: viewController!)

                        expect(navController.viewControllers).to(equal([viewController]))
                    }
                }
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
                expect(importUseCase.scanForImportableArgsForCall(callIndex: 0)) == URL(string: "https://example.com/feed.xml")
            }

            context("when the use case finds a feed") {
                let url = URL(string: "https://example.com/feed")!
                beforeEach {
                    showRootController()
                    importUseCase.scanForImportablePromises[0].resolve(.feed(url, 0))
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
                                action.handler(action)
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
                                action.handler(action)
                        }
                    }

                    it("should dismiss the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }

                    itBehavesLike("importing a feed")
                }
            }

            context("when the use case finds an opml file") {
                let url = URL(string: "https://example.com/feed")!
                beforeEach {
                    showRootController()
                    importUseCase.scanForImportablePromises[0].resolve(.opml(url, 0))
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
                                action.handler(action)
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
                                action.handler(action)
                        }
                    }

                    it("should dismiss the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }

                    it("should show an indicator that we're doing things") {
                        let indicator = subject.view.subviews.filter {
                            return $0.isKind(of: ActivityIndicator.classForCoder())
                        }.first as? ActivityIndicator
                        expect(indicator?.message) == "Loading feed list at https://example.com/feed"
                    }

                    it("asks the import use case to import the feed at the url") {
                        expect(importUseCase.importItemArgsForCall(callIndex: 0)) == url
                    }

                    describe("when the use case is finished") {
                        beforeEach {
                            importUseCase.importItemPromises[0].resolve(.success())
                        }

                        it("should remove the indicator") {
                            let indicator = subject.view.subviews.filter {
                                return $0.isKind(of: ActivityIndicator.classForCoder())
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
                let url = URL(string: "https://example.com/feed")!
                let feedURL = URL(string: "https://example.com/feed1")!

                beforeEach {
                    importUseCase.scanForImportablePromises[0].resolve(.webPage(url, [feedURL]))
                }

                it("should enable the addFeedButton") {
                    expect(subject.addFeedButton.isEnabled) == true
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
                let url = URL(string: "https://example.com/feed")!
                let feedURL1 = URL(string: "https://example.com/feed1")!
                let feedURL2 = URL(string: "https://example.com/feed2")!

                beforeEach {
                    importUseCase.scanForImportablePromises[0].resolve(.webPage(url, [feedURL1, feedURL2]))
                }

                it("should enable the addFeedButton") {
                    expect(subject.addFeedButton.isEnabled) == true
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
                                action.handler(action)
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
                let url = URL(string: "https://example.com/feed")!
                beforeEach {
                    importUseCase.scanForImportablePromises[0].resolve(.webPage(url, []))
                }

                it("should do nothing") {
                    expect(subject.presentedViewController).to(beNil())
                }
            }

            context("when the use case finds nothing") {
                let url = URL(string: "https://example.com/feed")!
                beforeEach {
                    importUseCase.scanForImportablePromises[0].resolve(.none(url))
                }

                it("should do nothing") {
                    expect(subject.presentedViewController).to(beNil())
                }
            }

            describe("Failing to load the page") {
                let err = NSError(domain: "", code: 0, userInfo: ["NSErrorFailingURLStringKey": "https://example.com"])
                context("before loading the page (network error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailProvisionalNavigation: nil, withError: err)
                    }

                    it("should hide the webview") {
                        expect(subject.loadingBar.isHidden) == true
                    }

                    it("shows an alert box") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                        if let alert = subject.presentedViewController as? UIAlertController {
                            expect(alert.title) == "Unable to load page"
                            expect(alert.message) == "The page at https://example.com failed to load"
                            expect(alert.actions.count) == 1
                            if let action = alert.actions.first {
                                expect(action.title) == "Ok"
                                action.handler(action)
                                expect(subject.presentedViewController).to(beNil())
                            }
                        }
                    }
                }

                context("trying to load the content (html rendering error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFail: nil, withError: err)
                    }

                    it("should hide the webview") {
                        expect(subject.loadingBar.isHidden) == true
                    }

                    it("shows an alert box") {
                        expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                        if let alert = subject.presentedViewController as? UIAlertController {
                            expect(alert.title) == "Unable to load page"
                            expect(alert.message) == "The page at https://example.com failed to load"
                            expect(alert.actions.count) == 1
                            if let action = alert.actions.first {
                                expect(action.title) == "Ok"
                                action.handler(action)
                                expect(subject.presentedViewController).to(beNil())
                            }
                        }
                    }
                }
            }

            describe("successfully loading a page") {
                beforeEach {
                    subject.webView(subject.webContent, didFinish: nil)
                }

                it("should hide the loadingBar") {
                    expect(subject.loadingBar.isHidden) == true
                }

                it("should allow the user to reload the page") {
                    expect(subject.navigationItem.rightBarButtonItem) == subject.reload
                }
            }
        }
    }
}

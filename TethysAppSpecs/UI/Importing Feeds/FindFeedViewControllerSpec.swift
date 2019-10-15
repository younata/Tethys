import Quick
import Nimble
import Tethys
import TethysKit
import SafariServices


class FindFeedViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FindFeedViewController!

        var navController: UINavigationController!
        var rootViewController: UIViewController!

        var webView: FakeWebView!
        var importUseCase: FakeImportUseCase!
        var analytics: FakeAnalytics!
        var notificationCenter: NotificationCenter!

        var recorder: NotificationRecorder!

        beforeEach {
            importUseCase = FakeImportUseCase()

            analytics = FakeAnalytics()

            notificationCenter = NotificationCenter()

            subject = FindFeedViewController(
                importUseCase: importUseCase,
                analytics: analytics,
                notificationCenter: notificationCenter
            )
            webView = FakeWebView()
            subject.webContent = webView

            rootViewController = UIViewController()
            navController = UINavigationController(rootViewController: subject)
            rootViewController.present(navController, animated: false, completion: nil)

            subject.view.layoutIfNeeded()

            recorder = NotificationRecorder()
            notificationCenter.addObserver(recorder!, selector: #selector(NotificationRecorder.received(notification:)),
                                           name: Notifications.reloadUI, object: subject)
        }

        describe("the theme") {
            it("sets the webView's background color") {
                expect(subject.webContent.backgroundColor).to(equal(Theme.backgroundColor))
            }

            it("sets the progress bar") {
                expect(subject.loadingBar.progressTintColor).to(equal(Theme.progressTintColor))
                expect(subject.loadingBar.trackTintColor).to(equal(Theme.progressTrackColor))
            }
        }

        it("tells analytics to log that the user viewed WebImport") {
            expect(analytics.logEventCallCount).to(equal(1))
            if (analytics.logEventCallCount > 0) {
                expect(analytics.logEventArgsForCall(0).0).to(equal("DidViewWebSubscribe"))
                expect(analytics.logEventArgsForCall(0).1).to(beNil())
            }
        }

        describe("accessibility") {
            it("configures the navField for accessibility") {
                expect(subject.navField.isAccessibilityElement).to(beTrue())
                expect(subject.navField.accessibilityLabel).to(equal("Navigate and search"))
            }

            it("configures the subscribe button for accessibility") {
                expect(subject.addFeedButton.isAccessibilityElement).to(beTrue())
                expect(subject.addFeedButton.accessibilityLabel).to(equal("Subscribe"))
                expect(subject.addFeedButton.accessibilityTraits).to(equal([.button]))
            }

            it("configures the back and forward buttons for accessibility") {
                expect(subject.back.isAccessibilityElement).to(beTrue())
                expect(subject.back.accessibilityLabel).to(equal("Previous page"))
                expect(subject.back.accessibilityTraits).to(equal([.button]))

                expect(subject.forward.isAccessibilityElement).to(beTrue())
                expect(subject.forward.accessibilityLabel).to(equal("Next page"))
                expect(subject.forward.accessibilityTraits).to(equal([.button]))
            }

            it("configures the reload button for accessibility") {
                expect(subject.reload.isAccessibilityElement).to(beTrue())
                expect(subject.reload.accessibilityLabel).to(equal("Reload"))
                expect(subject.reload.accessibilityTraits).to(equal([.button]))
            }
        }

        describe("the left bar button item") {
            it("indicates it'll close the controller") {
                expect(subject.navigationItem.leftBarButtonItem?.title).to(equal("Close"))
            }

            it("is configured for accessibility") {
                let button = subject.navigationItem.leftBarButtonItem

                expect(button?.isAccessibilityElement).to(beTrue())
                expect(button?.accessibilityTraits).to(equal([.button]))
                expect(button?.accessibilityLabel).to(equal("Close"))
            }

            describe("when tapped") {
                beforeEach {
                    subject.navigationItem.leftBarButtonItem?.tap()
                }

                it("dismisses the controller") {
                    expect(rootViewController.presentedViewController).to(beNil())
                }

                it("does not post a notification") {
                    expect(recorder.notifications).to(beEmpty())
                }
            }
        }

        describe("Looking up feeds on the interwebs") {
            beforeEach {
                subject.navField.text = "example.com"
                subject.navField.sendActions(for: .editingChanged)
                _ = subject.textFieldShouldReturn(subject.navField)
            }

            it("prepends 'https://' if it's not already there") {
                expect(subject.navField.text).to(equal("https://example.com"))
            }

            it("navigates the webview that url") {
                expect(webView.lastRequestLoaded?.url).to(equal(URL(string: "https://example.com")))
            }

            it("sets the navField's accessibility value to that url") {
                expect(subject.navField.accessibilityLabel).to(equal("Navigate and search"))
            }
        }

        describe("Entering an invalid url") {
            describe("when given a string with a single word") {
                beforeEach {
                    subject.navField.text = "notaurl"
                    _ = subject.textFieldShouldReturn(subject.navField)
                }

                it("searches duckduckgo for that text") {
                    expect(webView.lastRequestLoaded?.url).to(equal(URL(string: "https://duckduckgo.com/?q=notaurl")))
                }

                it("sets the navField's accessibility values") {
                    expect(subject.navField.accessibilityLabel).to(equal("Navigate and search"))
                    expect(subject.navField.accessibilityValue).to(equal("notaurl"))
                }
            }

            describe("when given a string with multiple words") {
                beforeEach {
                    subject.navField.text = "not a url"
                    _ = subject.textFieldShouldReturn(subject.navField)
                }

                it("searches duckduckgo for that text") {
                    expect(webView.lastRequestLoaded?.url).to(equal(URL(string: "https://duckduckgo.com/?q=not+a+url")))
                }

                it("sets the navField's accessibility values") {
                    expect(subject.navField.accessibilityLabel).to(equal("Navigate and search"))
                    expect(subject.navField.accessibilityValue).to(equal("not a url"))
                }
            }
        }

        describe("key commands") {
            it("can become first responder") {
                expect(subject.canBecomeFirstResponder).to(equal(true))
            }

            it("has 2 key commands initially") {
                expect(subject.keyCommands?.count).to(equal(2))
            }

            describe("the first command") {
                it("is bound to cmd+l") {
                    guard let keyCommand = subject.keyCommands?.first else { fail("No key commands found"); return }

                    expect(keyCommand.input).to(equal("l"))
                }

                it("is titled 'open URL'") {
                    guard let keyCommand = subject.keyCommands?.first else { fail("No key commands found"); return }

                    expect(keyCommand.discoverabilityTitle).to(equal("Open URL"))
                }
            }

            describe("the second command") {
                it("is bound to cmd+r") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("No key commands found"); return }

                    expect(keyCommand.input).to(equal("r"))
                }

                it("is titled 'Reload'") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("No key commands found"); return }

                    expect(keyCommand.discoverabilityTitle).to(equal("Reload"))
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
                    expect(subject.keyCommands?.count).to(equal(3))
                }

                it("is bound to cmd+i") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                    expect(keyCommand.input).to(equal("i"))
                }

                it("is titled 'Subscribe'") {
                    guard let keyCommand = subject.keyCommands?.last else { fail("precondition failed"); return }

                    expect(keyCommand.discoverabilityTitle).to(equal("Subscribe"))
                }
            }
        }

        describe("WKWebView and Delegates") {
            beforeEach {
                webView.fakeUrl = URL(string: "https://example.com/feed.xml")
                subject.webView(subject.webContent, didStartProvisionalNavigation: nil)
            }

            sharedExamples("subscribing to a feed") { (sharedContext: @escaping SharedExampleContext) in
                var url: URL!

                beforeEach {
                    url = (sharedContext()["url"] as? URL) ?? URL(string: "https://example.com/feed")!
                }

                it("asks the import use case to import the feed at the url") {
                    expect(importUseCase.importItemCalls.last).to(equal(url))
                }

                it("should show an indicator that we're doing things") {
                    let indicator = subject.view.subviews.filter {
                        return $0.isKind(of: ActivityIndicator.classForCoder())
                        }.first as? ActivityIndicator
                    expect(indicator?.message).to(equal("Loading feed at \(url.absoluteString)"))
                }

                describe("when the use case is finished") {
                    beforeEach {
                        importUseCase.importItemPromises[0].resolve(.success(()))
                    }

                    it("should remove the indicator") {
                        let indicator = navController.view.subviews.filter {
                            return $0.isKind(of: ActivityIndicator.classForCoder())
                            }.first
                        expect(indicator).to(beNil())
                    }

                    it("tells analytics to log that the user used WebImport") {
                        expect(analytics.logEventCallCount).to(equal(2))
                        if (analytics.logEventCallCount > 1) {
                            expect(analytics.logEventArgsForCall(1).0).to(equal("DidUseWebSubscribe"))
                            expect(analytics.logEventArgsForCall(1).1).to(beNil())
                        }
                    }

                    it("posts a notification telling other things to reload") {
                        expect(recorder.notifications).to(haveCount(1))
                        expect(recorder.notifications.last?.object as? NSObject).to(be(subject))
                    }

                    it("dismisses itself") {
                        expect(rootViewController.presentedViewController).to(beNil())
                    }
                }
            }

            it("shows the loadingBar") {
                expect(subject.loadingBar.isHidden).to(beFalse())
                expect(subject.loadingBar.progress).to(beCloseTo(0))
            }

            it("disables the addFeedButton") {
                expect(subject.addFeedButton.isEnabled).to(beFalse())
            }

            describe("context menu events") {
                describe("when the user tries to peek on a link") {
                    let element = FakeWKContentMenuElementInfo.new(linkURL: URL(string: "https://example.com/foo")!)
                    var contextMenuCalls: [UIContextMenuConfiguration?] = []

                    beforeEach {
                        contextMenuCalls = []

                        subject.webContent.uiDelegate?.webView?(
                            subject.webContent,
                            contextMenuConfigurationForElement: element,
                            completionHandler: { contextMenuCalls.append($0) }
                        )
                    }

                    it("presents another FindFeedViewController configured with that link") {
                        expect(contextMenuCalls).to(haveCount(1))
                        guard let contextMenu = contextMenuCalls.last else {
                            return expect(contextMenuCalls.last).toNot(beNil())
                        }
                        expect(contextMenu?.identifier as? NSURL).to(equal(URL(string: "https://example.com/foo")! as NSURL))
                        let viewController = contextMenu?.previewProvider?()
                        expect(viewController).to(beAnInstanceOf(FindFeedViewController.self))
                        expect(viewController).toNot(equal(subject))
                    }

                    it("replaces the navigation controller's view controller stack with just that view controller") {
                        let viewController = UIViewController()

                        let animator = FakeContextMenuAnimator(commitStyle: .pop, viewController: viewController)

                        subject.webContent.uiDelegate?.webView?(
                            subject.webContent,
                            contextMenuForElement: element,
                            willCommitWithAnimator: animator
                        )

                        expect(animator.addAnimationsCalls).to(beEmpty())
                        expect(animator.addCompletionCalls).to(haveCount(1))
                        animator.addCompletionCalls.last?()

                        expect(navController.viewControllers).to(equal([viewController]))
                    }
                }
            }

            describe("tapping the navField") {
                beforeEach {
                    subject.navField.delegate?.textFieldDidBeginEditing?(subject.navField)
                }

                it("fills the navField's text with the webView's url") {
                    expect(subject.navField.text).to(equal("https://example.com/feed.xml"))
                }

                it("goes back to the webView's title when loaded cancel is tapped") {
                    subject.cancelTextEntry.tap()

                    expect(subject.navField.text).to(beEmpty())
                }
            }

            it("asks the import use case to check if the page at the url has a feed") {
                expect(importUseCase.scanForImportableCalls.last).to(equal(URL(string: "https://example.com/feed.xml")))
            }

            context("when the use case finds a feed") {
                let url = URL(string: "https://example.com/feed")!
                beforeEach {
                    importUseCase.scanForImportablePromises[0].resolve(.feed(url, 0))
                }

                it("presents an alert") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                    if let alert = subject.presentedViewController as? UIAlertController {
                        expect(alert.title).to(equal("Feed Detected"))
                        expect(alert.message).to(equal("Subscribe to feed?"))

                        expect(alert.actions.count).to(equal(2))
                        if let dontsave = alert.actions.first {
                            expect(dontsave.title).to(equal("Don't Subscribe"))
                        }
                        if let save = alert.actions.last {
                            expect(save.title).to(equal("Subscribe"))
                        }
                    }
                }

                describe("tapping 'Don't Subscribe'") {
                    beforeEach {
                        if let alert = subject.presentedViewController as? UIAlertController,
                            let action = alert.actions.first {
                                action.handler?(action)
                        }
                    }

                    it("dismisses the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }

                    it("does not dismiss the controller") {
                        expect(rootViewController.presentedViewController).toNot(beNil())
                    }
                }

                describe("tapping 'Subscribe'") {
                    beforeEach {
                        if let alert = subject.presentedViewController as? UIAlertController,
                            let action = alert.actions.last {
                                action.handler?(action)
                        }
                    }

                    it("dismisses the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }

                    it("does not dismiss the controller") {
                        expect(rootViewController.presentedViewController).toNot(beNil())
                    }

                    itBehavesLike("subscribing to a feed")
                }
            }

            context("when the use case finds an opml file") {
                let url = URL(string: "https://example.com/feed")!
                beforeEach {
                    importUseCase.scanForImportablePromises[0].resolve(.opml(url, 0))
                }

                it("presents an alert") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                    if let alert = subject.presentedViewController as? UIAlertController {
                        expect(alert.title).to(equal("Feed List Detected"))
                        expect(alert.message).to(equal("Subscribe to all?"))

                        expect(alert.actions.count).to(equal(2))
                        if let dontsave = alert.actions.first {
                            expect(dontsave.title).to(equal("Don't Subscribe"))
                        }
                        if let save = alert.actions.last {
                            expect(save.title).to(equal("Subscribe"))
                        }
                    }
                }

                describe("tapping 'Don't Import'") {
                    beforeEach {
                        if let alert = subject.presentedViewController as? UIAlertController,
                            let action = alert.actions.first {
                                action.handler?(action)
                        }
                    }

                    it("dismisses the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }

                    it("does not dismiss the controller") {
                        expect(rootViewController.presentedViewController).toNot(beNil())
                    }
                }

                describe("tapping 'Import'") {
                    beforeEach {
                        if let alert = subject.presentedViewController as? UIAlertController,
                            let action = alert.actions.last {
                                action.handler?(action)
                        }
                    }

                    it("dismisses the alert") {
                        expect(subject.presentedViewController).to(beNil())
                    }

                    it("does not dismiss the controller") {
                        expect(rootViewController.presentedViewController).toNot(beNil())
                    }

                    it("shows an indicator that we're doing things") {
                        let indicator = subject.view.subviews.filter {
                            return $0.isKind(of: ActivityIndicator.classForCoder())
                        }.first as? ActivityIndicator
                        expect(indicator?.message).to(equal("Loading feed list at https://example.com/feed"))
                    }

                    it("asks the import use case to import the feed at the url") {
                        expect(importUseCase.importItemCalls.last).to(equal(url))
                    }

                    describe("when the use case is finished") {
                        beforeEach {
                            importUseCase.importItemPromises[0].resolve(.success(()))
                        }

                        it("removes the indicator") {
                            let indicator = subject.view.subviews.filter {
                                return $0.isKind(of: ActivityIndicator.classForCoder())
                                }.first
                            expect(indicator).to(beNil())
                        }

                        it("posts a notification telling other things to reload") {
                            expect(recorder.notifications).to(haveCount(1))
                            expect(recorder.notifications.last?.object as? NSObject).to(be(subject))
                        }

                        it("dismisses itself") {
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

                it("enables the addFeedButton") {
                    expect(subject.addFeedButton.isEnabled).to(beTrue())
                    expect(subject.addFeedButton.title).to(equal("Subscribe"))
                }

                describe("tapping on the addFeedButton") {
                    beforeEach {
                        subject.addFeedButton.tap()
                    }

                    itBehavesLike("subscribing to a feed") {
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

                it("enables the addFeedButton") {
                    expect(subject.addFeedButton.isEnabled).to(beTrue())
                }

                describe("tapping on the addFeedButton") {
                    beforeEach {
                        subject.addFeedButton.tap()
                    }

                    it("brings up a list of available feeds to import") {
                        expect(subject.presentedViewController).to(beAKindOf(UIAlertController.self))
                        if let alertController = subject.presentedViewController as? UIAlertController {
                            expect(alertController.preferredStyle).to(equal(UIAlertController.Style.actionSheet))
                            expect(alertController.actions).to(haveCount(3))

                            guard alertController.actions.count == 3 else { return }

                            let firstAction = alertController.actions[0]
                            expect(firstAction.title).to(equal("feed1"))

                            let secondAction = alertController.actions[1]
                            expect(secondAction.title).to(equal("feed2"))

                            let thirdAction = alertController.actions[2]
                            expect(thirdAction.title).to(equal("Cancel"))
                        }
                    }

                    context("tapping on one of the feed actions") {
                        beforeEach {
                            let actions = (subject.presentedViewController as? UIAlertController)?.actions ?? []
                            if actions.count == 3 {
                                let action = actions[1]
                                action.handler?(action)
                            } else {
                                fail("precondition failed")
                            }
                        }

                        itBehavesLike("subscribing to a feed") {
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

                it("does nothing") {
                    expect(subject.presentedViewController).to(beNil())
                }
            }

            context("when the use case finds nothing") {
                let url = URL(string: "https://example.com/feed")!
                beforeEach {
                    importUseCase.scanForImportablePromises[0].resolve(.none(url))
                }

                it("does nothing") {
                    expect(subject.presentedViewController).to(beNil())
                }
            }

            describe("Failing to load the page") {
                let err = NSError(domain: "", code: 0, userInfo: ["NSErrorFailingURLStringKey": "https://example.com"])

                context("before loading the page (network error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailProvisionalNavigation: nil, withError: err)
                    }

                    it("hides the loading bar") {
                        expect(subject.loadingBar.isHidden).to(beTrue())
                    }

                    it("tells the user that we were unable to load the page") {
                        expect(subject.webContent.lastHTMLStringLoaded).to(contain("Unable to load page"))
                        expect(subject.webContent.lastHTMLStringLoaded).to(contain("The page at https://example.com failed to load"))
                    }
                }

                context("trying to load the content (html rendering error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFail: nil, withError: err)
                    }

                    it("hides the webview") {
                        expect(subject.loadingBar.isHidden).to(beTrue())
                    }

                    it("tells the user that we were unable to load the page") {
                        expect(subject.webContent.lastHTMLStringLoaded).to(contain("Unable to load page"))
                        expect(subject.webContent.lastHTMLStringLoaded).to(contain("The page at https://example.com failed to load"))
                    }
                }
            }

            describe("successfully loading a page") {
                beforeEach {
                    subject.webView(subject.webContent, didFinish: nil)
                }

                it("hides the loadingBar") {
                    expect(subject.loadingBar.isHidden).to(beTrue())
                }

                it("allows the user to reload the page") {
                    expect(subject.navigationItem.rightBarButtonItem).to(be(subject.reload))
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

import Quick
import Nimble
import Ra
import rNews
import rNewsKit

class FindFeedViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FindFeedViewController! = nil

        var navController: UINavigationController! = nil

        var injector: Ra.Injector! = nil
        var webView: FakeWebView! = nil
        var feedFinder: FakeFeedFinder! = nil
        var dataWriter: FakeDataReadWriter! = nil

        beforeEach {
            injector = Ra.Injector(module: SpecInjectorModule())

            feedFinder = FakeFeedFinder()
            injector.bind(FeedFinder.self, to: feedFinder)

            dataWriter = FakeDataReadWriter()
            injector.bind(DataWriter.self, to: dataWriter)

            subject = injector.create(FindFeedViewController.self) as! FindFeedViewController
            webView = FakeWebView()
            subject.webContent = webView

            navController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("Looking up feeds on the interwebs") {
            it("should auto-prepend 'http://' if it's not already there") {
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
                let err = NSError(domain: "", code: 0, userInfo: [:])
                context("before loading the page (network error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailProvisionalNavigation: nil, withError: err)
                    }

                    it("should hide the webview") {
                        expect(subject.loadingBar.hidden).to(beTruthy())
                    }
                }

                context("trying to load the content (html rendering error)") {
                    beforeEach {
                        subject.webView(subject.webContent, didFailNavigation: nil, withError: err)
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

                it("should look for a not-already imported feed linked from the webpage") {
                    expect(feedFinder.didAttemptToFindFeed).to(beTruthy())
                }

                context("when a feed is found") {
                    beforeEach {
                        feedFinder.findFeedCallback("https://example.com/feed.xml")
                    }

                    it("should enable the addFeedButton") {
                        expect(subject.addFeedButton.enabled).to(beTruthy())
                    }

                    describe("tapping on the addFeedButton") {
                        beforeEach {
                            subject.addFeedButton.tap()
                        }

                        it("should create a new feed") {
                            expect(dataWriter.didCreateFeed).to(beTruthy())
                        }

                        it("should show an indicator that we're doing things") {
                            let indicator = navController.view.subviews.filter {
                                return $0.isKindOfClass(ActivityIndicator.classForCoder())
                            }.first as? ActivityIndicator
                            expect(indicator?.message).to(equal("Loading feed at https://example.com/feed.xml"))
                        }

                        describe("when the feed is created") {
                            beforeEach {
                                let feed = Feed(title: "", url: NSURL(string: ""), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                                dataWriter.newFeedCallback(feed)
                            }

                            it("should save the new feed") {
                                let feed = Feed(title: "", url: NSURL(string: "https://example.com/feed.xml"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                                expect(dataWriter.lastSavedFeed).to(equal(feed))
                            }

                            it("should try to update feeds") {
                                expect(dataWriter.didUpdateFeeds).to(beTruthy())
                            }

                            describe("when the feeds update") {
                                var window: UIWindow! = nil
                                var rootViewController: UIViewController! = nil
                                beforeEach {
                                    window = UIWindow(frame: CGRectZero)
                                    window.makeKeyAndVisible()
                                    rootViewController = UIViewController()
                                    window.rootViewController = rootViewController

                                    rootViewController.presentViewController(navController, animated: false, completion: nil)
                                    expect(rootViewController.presentedViewController).toNot(beNil())
                                    dataWriter.updateFeedsCompletion([], [])
                                }

                                afterEach {
                                    window.resignKeyWindow()
                                    window = nil
                                }

                                it("should remove the indicator") {
                                    let indicator = navController.view.subviews.filter {
                                        return $0.isKindOfClass(ActivityIndicator.classForCoder())
                                    }.first
                                    expect(indicator).to(beNil())
                                }

                                it("should dismiss itself") {
                                    expect(rootViewController.presentedViewController).toEventually(beNil())
                                }
                            }
                        }
                    }
                }

                context("when a feed is not found") {
                    beforeEach {
                        feedFinder.findFeedCallback(nil)
                    }

                    it("should do nothing") {
                        expect(subject.addFeedButton.enabled).to(beFalsy())
                    }
                }
            }
        }
    }
}

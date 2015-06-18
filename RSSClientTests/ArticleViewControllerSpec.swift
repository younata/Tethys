import Quick
import Nimble
import Ra
import rNews
import TOBrowserActivityKit
import WebKit

class ArticleViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ArticleViewController! = nil
        var injector: Injector! = nil
        var navigationController: UINavigationController! = nil
        var dataManager: DataManagerMock! = nil

        beforeEach {
            injector = Injector()
            dataManager = DataManagerMock()
            injector.bind(DataManager.self, to: dataManager)

            subject = injector.create(ArticleViewController.self) as! ArticleViewController

            navigationController = UINavigationController(rootViewController: subject)

            subject.view.layoutIfNeeded()
        }

        it("should create/set a user activity") {
            expect(subject.userActivity).toNot(beNil())
            if let activity = subject.userActivity {
                expect(activity.activityType).to(equal("com.rachelbrindle.rssclient.article"))
                expect(activity.title).to(equal("Reading Article"))
            }
        }

        it("should invalidate the user activity upon dealloc") {
            if let activity = subject.userActivity {
                navigationController = nil
                injector = nil
                subject = nil
                expect(activity.valid).to(beFalsy())
            }
        }

        describe("continuing from user activity") {
//            let article = Article(title: "article", link: NSURL(string: "https://example.com"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "", read: false, feed: nil, flags: [], enclosures: [])

            beforeEach {
                let activityType = "com.rachelbrindle.rssclient.article"
                let userActivity = NSUserActivity(activityType: activityType)
                userActivity.title = NSLocalizedString("Reading Article", comment: "")

                subject.restoreUserActivityState(userActivity)
            }

            // TODO: this
//            it("should load up the old article") {
//
//            }
        }

        describe("setting the article") {
            let article = Article(title: "article", link: NSURL(string: "https://example.com"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "", read: false, feed: nil, flags: [], enclosures: [])

            beforeEach {
                subject.article = article
            }

            it("should mark the article as read") {
                expect(article.read).to(beTruthy())
                expect(dataManager.lastArticleMarkedRead).to(equal(article))
            }

            it("should update the user activity") {
                expect(subject.userActivity).toNot(beNil())
                if let activity = subject.userActivity {
                    expect(activity.active).to(beTruthy())

                    expect(activity.userInfo).toNot(beNil())
                    if let userInfo = activity.userInfo {
                        expect(userInfo.keys.count).to(equal(3))
                        expect(userInfo["feed"] as? String).to(equal(""))
                        expect(userInfo["article"] as? String).to(equal("identifier"))
                        expect(userInfo["showingContent"] as? Bool).to(beTruthy())
                    }

                    expect(activity.webpageURL).to(equal(NSURL(string: "https://example.com")))
                    expect(activity.needsSave).to(beTruthy())

                    navigationController = nil
                    injector = nil
                    subject = nil
                    expect(activity.valid).to(beFalsy())
                }
            }

            describe("tapping the share button") {
                beforeEach {
                    subject.shareButton.tap()
                }

                it("should bring up an activity view controller") {
                    expect(subject.presentedViewController).toEventually(beAnInstanceOf(UIActivityViewController.self))
                    if let activityViewController = subject.presentedViewController as? UIActivityViewController {
                        expect(activityViewController.activityItems().count).to(equal(1))
                        expect(activityViewController.activityItems().first as? NSURL).to(equal(NSURL(string: "https://example.com")))

                        let safari = TOActivitySafari()
                        let chrome = TOActivityChrome()
                        expect(activityViewController.applicationActivities() as? [NSObject]).to(equal([safari, chrome])) // Fixme: test for popover controller and use that.
                    }
                }
            }

            it("should set the the content/link to content") {
                expect(subject.toggleContentButton.title).to(equal("Link"))
            }

            describe("tapping content/link button") {
                beforeEach {
                    subject.toggleContentButton.tap()
                }

                it("should show the link") {
                    expect(subject.content.URL).to(equal(NSURL(string: "https://example.com")))
                }

                it("should update it's title") {
                    expect(subject.toggleContentButton.title).toEventually(equal("Content"))
                }

                it("should update the userActivity") {
                    if let userInfo = subject.userActivity?.userInfo {
                        expect(userInfo["showingContent"] as? Bool).to(beTruthy())
                        expect(userInfo["url"]).to(beNil())
                    }
                }

                describe("tapping it again") {
                    beforeEach {
                        subject.toggleContentButton.tap()
                    }

                    it("should show the content again") {
                        expect(subject.content.URL).toEventually(beNil())
                    }

                    it("should update it's title") {
                        expect(subject.toggleContentButton.title).to(equal("Link"))
                    }

                    it("should update the userActivity") {
                        if let userInfo = subject.userActivity?.userInfo {
                            expect(userInfo["showingContent"] as? Bool).to(beFalsy())
                            expect(userInfo["url"] as? NSURL).to(equal(article.link))
                        }
                    }
                }
            }

            describe("loading article content") {
                var webView: WKWebView! = nil

                beforeEach {
                    webView = subject.content
                }

                describe("begining to navigate") {
                    beforeEach {
                        webView.navigationDelegate?.webView?(webView, didStartProvisionalNavigation: nil)
                    }

                    it("should show a progress bar with 0 progress") {
                        expect(subject.loadingBar.progress).to(equal(0))
                        expect(subject.loadingBar.hidden).to(beFalsy())
                    }

                    it("should enable the forward/back if it can") {
                        if let items = subject.navigationItem.rightBarButtonItems, forward = items.first, back = items.last {
                            expect(forward.enabled).to(equal(webView.canGoForward))
                            expect(back.enabled).to(equal(webView.canGoBack))
                        }
                    }

                    context("successfully navigating") {
                        beforeEach {
                            webView.navigationDelegate?.webView?(webView, didFinishNavigation: nil)
                        }

                        it("should hide the loadingBar") {
                            expect(subject.loadingBar.hidden).to(beTruthy())
                        }

                        it("should update the userActivity") {
                            if let activity = subject.userActivity {
                                expect(activity.userInfo?["url"] as? NSURL).to(equal(webView.URL))
                                expect(activity.webpageURL).to(equal(webView.URL))
                            }
                        }
                    }

                    context("failing to navigate") {
                        beforeEach {
                            webView.navigationDelegate?.webView?(webView, didFailNavigation: nil, withError: NSError(domain: "", code: 0, userInfo: [:]))
                        }

                        it("should hide the loadingBar") {
                            expect(subject.loadingBar.hidden).to(beTruthy())
                        }
                    }
                }
            }
        }
    }
}
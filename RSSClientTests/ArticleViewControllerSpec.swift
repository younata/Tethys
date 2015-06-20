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

        describe("continuing from user activity") {
            let article = Article(title: "article", link: NSURL(string: "https://example.com/article"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "<h1>hi</h1>", read: false, feed: nil, flags: [], enclosures: [])

            beforeEach {
                subject.article = article
            }

            context("when we were showing the content") {
                beforeEach {
                    let activityType = "com.rachelbrindle.rssclient.article"
                    let userActivity = NSUserActivity(activityType: activityType)
                    userActivity.title = NSLocalizedString("Reading Article", comment: "")

                    userActivity.userInfo = [
                        "feed": "",
                        "article": "",
                        "showingContent": true
                    ]

                    subject.restoreUserActivityState(userActivity)
                }

                it("should show the content") {
                    expect(subject.toggleContentButton.title).to(equal("Link"))
                }
            }

            context("when we were showing a link") {
                beforeEach {
                    let activityType = "com.rachelbrindle.rssclient.article"
                    let userActivity = NSUserActivity(activityType: activityType)
                    userActivity.title = NSLocalizedString("Reading Article", comment: "")

                    userActivity.userInfo = [
                        "feed": "",
                        "article": "",
                        "showingContent": false
                    ]

                    subject.restoreUserActivityState(userActivity)
                }

                it("should load the article's link") {
                    expect(subject.content.lastRequestLoaded?.URL).to(equal(NSURL(string: "https://example.com/article")))
                }
            }

            context("when we had a webpageURL") {
                beforeEach {
                    let activityType = "com.rachelbrindle.rssclient.article"
                    let userActivity = NSUserActivity(activityType: activityType)
                    userActivity.title = NSLocalizedString("Reading Article", comment: "")

                    userActivity.userInfo = [
                        "feed": "",
                        "article": "",
                        "showingContent": true
                    ]
                    userActivity.webpageURL = NSURL(string: "http://example.com/resumeURL")

                    subject.restoreUserActivityState(userActivity)
                }

                it("should load the webpage") {
                    expect(subject.content.lastRequestLoaded?.URL).to(equal(NSURL(string: "http://example.com/resumeURL")))
                }
            }
        }

        describe("setting the article") {
            let article = Article(title: "article", link: NSURL(string: "https://google.com/"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "", read: false, feed: nil, flags: [], enclosures: [])

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

                    expect(activity.webpageURL).to(equal(article.link))
                    expect(activity.needsSave).to(beTruthy())

                    navigationController = nil
                    injector = nil
                    subject = nil
                    expect(activity.valid).to(beFalsy())
                }
            }

            describe("tapping the share button") {
                var window: UIWindow! = nil
                beforeEach {
                    window = UIWindow()
                    window.makeKeyAndVisible()
                    window.rootViewController = navigationController
                    subject.shareButton.tap()
                }

                afterEach {
                    window.resignKeyWindow()
                    window = nil
                }

                it("should bring up an activity view controller") {
                    expect(subject.presentedViewController).toEventually(beAnInstanceOf(UIActivityViewController.self))
                    if let activityViewController = subject.presentedViewController as? UIActivityViewController {
                        expect(activityViewController.activityItems().count).to(equal(1))
                        expect(activityViewController.activityItems().first as? NSURL).to(equal(article.link))

                        expect(activityViewController.applicationActivities() as? [NSObject]).toNot(beNil())
                        if let activities = activityViewController.applicationActivities() as? [NSObject] {
                            expect(activities.first).to(beAnInstanceOf(TOActivitySafari.self))
                            expect(activities.last).to(beAnInstanceOf(TOActivityChrome.self))
                        }
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
                    expect(subject.content.lastRequestLoaded?.URL).to(equal(article.link))
                }

                it("should update it's title") {
                    expect(subject.toggleContentButton.title).to(equal("Content"))
                }

                it("should update the userActivity") {
                    if let activity = subject.userActivity, let userInfo = activity.userInfo {
                        expect(userInfo["showingContent"] as? Bool).to(beFalsy())
                        expect(activity.webpageURL).to(equal(article.link))
                    }
                }

                describe("tapping it again") {
                    beforeEach {
                        subject.toggleContentButton.tap()
                    }

                    it("should show the content again") {
                        expect(subject.content.URL).to(beNil())
                    }

                    it("should update it's title") {
                        expect(subject.toggleContentButton.title).to(equal("Link"))
                    }

                    it("should update the userActivity") {
                        if let activity = subject.userActivity, let userInfo = activity.userInfo {
                            expect(userInfo["showingContent"] as? Bool).to(beTruthy())
                            expect(activity.webpageURL).to(equal(article.link))
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

                    context("successfully navigating") {
                        beforeEach {
                            webView.currentURL = NSURL(string: "https://example.com/link")
                            webView.navigationDelegate?.webView?(webView, didFinishNavigation: nil)
                        }

                        it("should hide the loadingBar") {
                            expect(subject.loadingBar.hidden).to(beTruthy())
                        }

                        it("should update the userActivity") {
                            if let activity = subject.userActivity {
                                expect(activity.webpageURL).to(equal(webView.currentURL))
                            }
                        }

                        it("should enable the forward/back if it can") {
                            if let items = subject.navigationItem.rightBarButtonItems, forward = items.first, back = items.last {
                                expect(forward.enabled).to(equal(webView.canGoForward))
                                expect(back.enabled).to(equal(webView.canGoBack))
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

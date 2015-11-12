import Quick
import Nimble
import Ra
import rNews
import TOBrowserActivityKit
import WebKit
import rNewsKit

class ArticleViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ArticleViewController! = nil
        var injector: Injector! = nil
        var navigationController: UINavigationController! = nil
        var dataWriter: FakeDataReadWriter! = nil
        var themeRepository: FakeThemeRepository! = nil

        beforeEach {
            injector = Injector()

            dataWriter = FakeDataReadWriter()
            injector.bind(DataWriter.self, to: dataWriter)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, to: themeRepository)

            subject = injector.create(ArticleViewController.self) as! ArticleViewController

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should update the navigation bar background") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
            }

            it("should update the content's background color") {
                expect(subject.content.backgroundColor).to(equal(themeRepository.backgroundColor))
            }

            it("should update the toolbar") {
                expect(subject.navigationController?.toolbar.barStyle).to(equal(themeRepository.barStyle))
            }
        }

        describe("Key Commands") {
            it("can become first responder") {
                expect(subject.canBecomeFirstResponder()).to(beTruthy())
            }

            func hasKindsOfKeyCommands(expectedCommands: [UIKeyCommand], discoveryTitles: [String]) {
                let keyCommands = subject.keyCommands
                expect(keyCommands).toNot(beNil())
                guard let commands = keyCommands else {
                    return
                }

                expect(commands.count).to(equal(expectedCommands.count))
                for (idx, cmd) in commands.enumerate() {
                    let expectedCmd = expectedCommands[idx]
                    expect(cmd.input).to(equal(expectedCmd.input))
                    expect(cmd.modifierFlags).to(equal(expectedCmd.modifierFlags))

                    if #available(iOS 9.0, *) {
                        let expectedTitle = discoveryTitles[idx]
                        expect(cmd.discoverabilityTitle).to(equal(expectedTitle))
                    }
                }
            }

            let article = Article(title: "article", link: NSURL(string: "https://example.com/article"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "<h1>hi</h1>", read: false, feed: nil, flags: [], enclosures: [])
            let article1 = Article(title: "article1", link: nil, summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier1", content: "<h1>hi</h1>", read: false, feed: nil, flags: [], enclosures: [])
            let article2 = Article(title: "article2", link: NSURL(string: "https://example.com/article"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier2", content: "<h1>hi</h1>", read: false, feed: nil, flags: [], enclosures: [])
            let article3 = Article(title: "article3", link: NSURL(string: "https://example.com/article"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier3", content: "<h1>hi</h1>", read: false, feed: nil, flags: [], enclosures: [])

            context("when there is only one article") {
                beforeEach {
                    subject.article = article
                    subject.articles = [article]
                    subject.lastArticleIndex = 0
                }

                it("should not list the next/previous article commands") {
                    let expectedCommands = [
                        UIKeyCommand(input: "r", modifierFlags: .Shift, action: ""),
                        UIKeyCommand(input: "l", modifierFlags: .Command, action: ""),
                        UIKeyCommand(input: "s", modifierFlags: .Command, action: ""),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Toggle Read",
                        "Toggle View Content/Link",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }

            context("when at the beginning of an article list") {
                beforeEach {
                    subject.article = article2
                    subject.articles = [article, article1, article2, article3]
                    subject.lastArticleIndex = 0
                }

                it("should not list the previous article command") {
                    let expectedCommands = [
                        UIKeyCommand(input: "n", modifierFlags: .Control, action: ""),
                        UIKeyCommand(input: "r", modifierFlags: .Shift, action: ""),
                        UIKeyCommand(input: "l", modifierFlags: .Command, action: ""),
                        UIKeyCommand(input: "s", modifierFlags: .Command, action: ""),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Next Article",
                        "Toggle Read",
                        "Toggle View Content/Link",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }

            context("when at the end of an article list") {
                beforeEach {
                    subject.article = article3
                    subject.articles = [article, article1, article2, article3]
                    subject.lastArticleIndex = 3
                }

                it("should not list the next article command") {
                    let expectedCommands = [
                        UIKeyCommand(input: "p", modifierFlags: .Control, action: ""),
                        UIKeyCommand(input: "r", modifierFlags: .Shift, action: ""),
                        UIKeyCommand(input: "l", modifierFlags: .Command, action: ""),
                        UIKeyCommand(input: "s", modifierFlags: .Command, action: ""),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Previous Article",
                        "Toggle Read",
                        "Toggle View Content/Link",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }

            context("when viewing an article that does not have a link") {
                beforeEach {
                    subject.article = article1
                    subject.articles = [article, article1, article2, article3]
                    subject.lastArticleIndex = 1
                }

                it("should not list the next article command") {
                    let expectedCommands = [
                        UIKeyCommand(input: "p", modifierFlags: .Control, action: ""),
                        UIKeyCommand(input: "n", modifierFlags: .Control, action: ""),
                        UIKeyCommand(input: "r", modifierFlags: .Shift, action: ""),
                        UIKeyCommand(input: "s", modifierFlags: .Command, action: ""),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Previous Article",
                        "Next Article",
                        "Toggle Read",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }

            context("when in the middle of an article list") {
                beforeEach {
                    subject.article = article2
                    subject.articles = [article, article1, article2, article3]
                    subject.lastArticleIndex = 2
                }

                it("should list the complete list of key commands") {
                    let expectedCommands = [
                        UIKeyCommand(input: "p", modifierFlags: .Control, action: ""),
                        UIKeyCommand(input: "n", modifierFlags: .Control, action: ""),
                        UIKeyCommand(input: "r", modifierFlags: .Shift, action: ""),
                        UIKeyCommand(input: "l", modifierFlags: .Command, action: ""),
                        UIKeyCommand(input: "s", modifierFlags: .Command, action: ""),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Previous Article",
                        "Next Article",
                        "Toggle Read",
                        "Toggle View Content/Link",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }
        }

        it("should create/set a user activity") {
            expect(subject.userActivity).toNot(beNil())
            if let activity = subject.userActivity {
                expect(activity.activityType).to(equal("com.rachelbrindle.rssclient.article"))
                expect(activity.title).to(equal("Reading Article"))
                if #available(iOS 9.0, *) {
                    expect(activity.eligibleForSearch).to(beTruthy())
                    expect(activity.eligibleForPublicIndexing).to(beFalsy())
                }
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
            let article = Article(title: "article", link: NSURL(string: "https://google.com/"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "", read: false, feed: nil, flags: ["a"], enclosures: [])

            beforeEach {
                subject.article = article
            }

            it("should mark the article as read") {
                expect(article.read).to(beTruthy())
                expect(dataWriter.lastArticleMarkedRead).to(equal(article))
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

                    if #available(iOS 9.0, *) {
                        expect(activity.keywords).to(equal(Set(["article", "summary", "rachel",  "a"])))
                    }

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
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIActivityViewController.self))
                    if let activityViewController = subject.presentedViewController as? UIActivityViewController {
                        expect(activityViewController.activityItems().count).to(equal(1))
                        expect(activityViewController.activityItems().first as? NSURL).to(equal(subject.content.URL ?? article.link))

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

import Quick
import Nimble
import Ra
import rNews
import TOBrowserActivityKit
import SafariServices
@testable import rNewsKit

class ArticleViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ArticleViewController! = nil
        var injector: Injector! = nil
        var navigationController: UINavigationController! = nil
        var dataWriter: FakeDataReadWriter! = nil
        var themeRepository: FakeThemeRepository! = nil
        var urlOpener: FakeUrlOpener! = nil

        beforeEach {
            injector = Injector()

            dataWriter = FakeDataReadWriter()
            injector.bind(DataWriter.self, toInstance: dataWriter)

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            urlOpener = FakeUrlOpener()
            injector.bind(UrlOpener.self, toInstance: urlOpener)

            subject = injector.create(ArticleViewController)!

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

            it("should update the scroll indicator style") {
                expect(subject.content.scrollView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
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

            let article = Article(title: "article", link: NSURL(string: "https://example.com/article"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "<h1>hi</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
            let article1 = Article(title: "article1", link: nil, summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier1", content: "<h1>hi</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
            let article2 = Article(title: "article2", link: NSURL(string: "https://example.com/article"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier2", content: "<h1>hi</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
            let article3 = Article(title: "article3", link: NSURL(string: "https://example.com/article"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier3", content: "<h1>hi</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

            context("when there is only one article") {
                beforeEach {
                    subject.setArticle(article, read: false, show: false)
                    subject.articles = DataStoreBackedArray([article])
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
                        "Open Article in WebView",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }

            context("when at the beginning of an article list") {
                beforeEach {
                    subject.setArticle(article2, read: false, show: false)
                    subject.articles = DataStoreBackedArray([article, article1, article2, article3])
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
                        "Open Article in WebView",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }

            context("when at the end of an article list") {
                beforeEach {
                    subject.setArticle(article3, read: false, show: false)
                    subject.articles = DataStoreBackedArray([article, article1, article2, article3])
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
                        "Open Article in WebView",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }

            context("when viewing an article that does not have a link") {
                beforeEach {
                    subject.setArticle(article1, read: false, show: false)
                    subject.articles = DataStoreBackedArray([article, article1, article2, article3])
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
                    subject.setArticle(article2, read: false, show: false)
                    subject.articles = DataStoreBackedArray([article, article1, article2, article3])
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
                        "Open Article in WebView",
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
                expect(activity.delegate).toNot(beNil())
                if #available(iOS 9.0, *) {
                    expect(activity.eligibleForSearch).to(beTruthy())
                    expect(activity.eligibleForPublicIndexing).to(beFalsy())
                }
            }
        }

        describe("continuing from user activity") {
            let article = Article(title: "article", link: NSURL(string: "https://example.com/article"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "<h1>hi</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

            beforeEach {
                subject.setArticle(article)

                let activityType = "com.rachelbrindle.rssclient.article"
                let userActivity = NSUserActivity(activityType: activityType)
                userActivity.title = NSLocalizedString("Reading Article", comment: "")

                userActivity.userInfo = [
                    "feed": "",
                    "article": ""
                ]

                subject.restoreUserActivityState(userActivity)
            }

            it("should show the content") {
                expect(subject.content.loadedHTMLString()).to(contain(article.content))
            }
        }

        describe("setting the article") {
            let article = Article(title: "article", link: NSURL(string: "https://google.com/"), summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "content!", read: false, estimatedReadingTime: 0, feed: nil, flags: ["a"], enclosures: [])
            let articleWOContent = Article(title: "article", link: NSURL(string: "https://google.com/"), summary: "this was a summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: ["a"], enclosures: [])
            let feed = Feed(title: "feed", url: NSURL(string: "https://example.com"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)

            beforeEach {
                article.feed = feed
                feed.addArticle(article)
                subject.setArticle(article)
            }

            it("should mark the article as read") {
                expect(article.read).to(beTruthy())
                expect(dataWriter.lastArticleMarkedRead).to(equal(article))
            }

            it("should load just the description if the article has no content") {
                subject.setArticle(articleWOContent)

                expect(subject.content.loadedHTMLString()).to(contain(articleWOContent.summary))
            }

            if #available(iOS 9, *) {
                it("should enable link preview with 3d touch on iOS 9") {
                    expect(subject.content.allowsLinkPreview).to(beTruthy())
                }
            }

            it("should include the share button in the toolbar, and the open in safari button only if we're on iOS 9") {
                expect(subject.toolbarItems?.contains(subject.shareButton)).to(beTruthy())
                if #available(iOS 9, *) {
                    expect(subject.toolbarItems?.contains(subject.openInSafariButton)).to(beTruthy())
                } else {
                    expect(subject.toolbarItems?.contains(subject.openInSafariButton)).to(equal(false))
                }
            }

            it("should exclude the open in safari button if the article has no associated link") {
                let article2 = Article(title: "article2", link: nil, summary: "summary", author: "rachel", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "<h1>Hello World</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: ["a"], enclosures: [])
                let feed2 = Feed(title: "feed2", url: NSURL(string: "https://example.com"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                article2.feed = feed2
                feed2.addArticle(article2)

                subject.setArticle(article2)

                expect(subject.toolbarItems?.contains(subject.shareButton)).to(beTruthy())
                expect(subject.toolbarItems?.contains(subject.openInSafariButton)).to(equal(false))
            }

            it("should update the user activity") {
                expect(subject.userActivity).toNot(beNil())
                if let activity = subject.userActivity {
                    expect(activity.active).to(beTruthy())

                    expect(activity.userInfo).toNot(beNil())
                    if let userInfo = activity.userInfo {
                        expect(userInfo.keys.count).to(equal(2))
                        expect(userInfo["feed"] as? String).to(equal("feed"))
                        expect(userInfo["article"] as? String).to(equal(""))
                    }

                    expect(activity.webpageURL).to(equal(article.link))
                    expect(activity.needsSave).to(beTruthy())
                    expect(activity.title).to(equal("\(feed.title): \(article.title)"))

                    if #available(iOS 9.0, *) {
                        expect(activity.keywords).to(equal(Set(["article", "summary", "rachel",  "a"])))
                    }

                    navigationController = nil
                    injector = nil
                    subject = nil
                    expect(activity.valid).to(beFalsy())
                }
            }

            describe("saving the user activity") {
                beforeEach {
                    expect(subject.userActivity).toNot(beNil())
                    if let activity = subject.userActivity {
                        activity.userInfo = nil

                        activity.delegate?.userActivityWillSave?(activity)
                    }
                }

                it("actually writes the data to disk") {
                    if let activity = subject.userActivity {
                        expect(activity.userInfo).toNot(beNil())
                        if let userInfo = activity.userInfo {
                            expect(userInfo.keys.count).to(equal(2))
                            expect(userInfo["feed"] as? String).to(equal("feed"))
                            expect(userInfo["article"] as? String).to(equal(""))
                        }
                    }
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
                        expect(activityViewController.activityItems().first as? NSURL).to(equal(article.link))

                        expect(activityViewController.applicationActivities() as? [NSObject]).toNot(beNil())
                        if let activities = activityViewController.applicationActivities() as? [NSObject] {
                            expect(activities.first).to(beAnInstanceOf(TOActivitySafari.self))
                            expect(activities.last).to(beAnInstanceOf(TOActivityChrome.self))
                        }
                    }
                }
            }
            
            it("should open the article in an SFSafariViewController if the open in safari button is tapped") {
                subject.openInSafariButton.tap()

                if #available(iOS 9, *) {
                    expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                } else {
                    expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                }
            }

            it("should open any link tapped in system safari (iOS <9) or an SFSafariViewController (iOS 9+)") {
                let url = NSURL(string: "https://google.com")!
                let shouldInteract = subject.content.delegate?.webView?(subject.content, shouldStartLoadWithRequest: NSURLRequest(URL: url), navigationType: .LinkClicked)
                expect(shouldInteract).to(beFalsy())
                if #available(iOS 9, *) {
                    expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                } else {
                    expect(urlOpener.url).to(equal(url))
                }
            }
        }
    }
}

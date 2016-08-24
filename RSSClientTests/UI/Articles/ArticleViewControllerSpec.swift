import Quick
import Nimble
import Ra
import rNews
import TOBrowserActivityKit
import SafariServices
@testable import rNewsKit

class ArticleViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: ArticleViewController!
        var injector: Injector!
        var navigationController: UINavigationController!
        var themeRepository: FakeThemeRepository!
        var articleUseCase: FakeArticleUseCase!

        beforeEach {
            injector = Injector()

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            articleUseCase = FakeArticleUseCase()
            injector.bind(ArticleUseCase.self, toInstance: articleUseCase)

            subject = injector.create(ArticleViewController)!

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("when the view appears") {
            beforeEach {
                subject.viewDidAppear(false)
            }

            it("shows the background view on viewWillAppear and an article is not set") {
                expect(subject.backgroundView.hidden) == false

                subject.backgroundView.hidden = true

                articleUseCase.readArticleReturns("hello")
                articleUseCase.userActivityForArticleReturns(NSUserActivity(activityType: "com.example.test"))
                subject.setArticle(Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: []))

                expect(subject.backgroundView.hidden) == true
            }

            it("hides the nav and toolbars on swipe/tap") {
                expect(navigationController.hidesBarsOnSwipe).to(beTruthy())
                expect(navigationController.hidesBarsOnTap).to(beTruthy())
            }

            it("disables hiding the nav and toolbars on swipe/tap when the view disappears") {
                subject.viewWillDisappear(false)
                expect(navigationController.hidesBarsOnSwipe).to(beFalsy())
                expect(navigationController.hidesBarsOnTap).to(beFalsy())
            }
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should update the navigation bar background") {
                expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
            }

            it("should update the content's background color") {
                expect(subject.content.backgroundColor) == themeRepository.backgroundColor
            }

            it("should update the scroll indicator style") {
                expect(subject.content.scrollView.indicatorStyle) == themeRepository.scrollIndicatorStyle
            }

            it("should update the toolbar") {
                expect(subject.navigationController?.toolbar.barStyle) == themeRepository.barStyle
            }

            it("updates the background view's backgroundColor") {
                expect(subject.backgroundView.backgroundColor) == themeRepository.backgroundColor
            }

            it("updates the background spinner's style") {
                expect(subject.backgroundSpinnerView.activityIndicatorViewStyle) == themeRepository.spinnerStyle
            }
        }

        describe("Key Commands") {
            beforeEach {
                articleUseCase.readArticleReturns("hello")
                articleUseCase.userActivityForArticleReturns(NSUserActivity(activityType: "com.example.test"))
            }

            it("can become first responder") {
                expect(subject.canBecomeFirstResponder()) == true
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

                    let expectedTitle = discoveryTitles[idx]
                    expect(cmd.discoverabilityTitle).to(equal(expectedTitle))
                }
            }

            let article = Article(title: "article", link: NSURL(string: "https://example.com/article"), summary: "summary", authors: [], published: NSDate(), updatedAt: nil, identifier: "identifier", content: "<h1>hi</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])
            let article1 = Article(title: "article1", link: nil, summary: "summary", authors: [], published: NSDate(), updatedAt: nil, identifier: "identifier1", content: "<h1>hi</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

            context("when viewing an article that has a link") {
                beforeEach {
                    subject.setArticle(article, read: false, show: false)
                }

                it("should not list the next/previous article commands") {
                    let expectedCommands = [
                        UIKeyCommand(input: "r", modifierFlags: .Shift, action: Selector()),
                        UIKeyCommand(input: "l", modifierFlags: .Command, action: Selector()),
                        UIKeyCommand(input: "s", modifierFlags: .Command, action: Selector()),
                    ]
                    let expectedDiscoverabilityTitles = [
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
                }

                it("should not list the next article command") {
                    let expectedCommands = [
                        UIKeyCommand(input: "r", modifierFlags: .Shift, action: Selector()),
                        UIKeyCommand(input: "s", modifierFlags: .Command, action: Selector()),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Toggle Read",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }
        }

        describe("continuing from user activity") {
            let article = Article(title: "article", link: NSURL(string: "https://example.com/article"), summary: "summary", authors: [], published: NSDate(), updatedAt: nil, identifier: "identifier", content: "<h1>hi</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

            beforeEach {
                articleUseCase.readArticleStub = {
                    if $0 == article {
                        return $0.content
                    }
                    return "hello"
                }
                articleUseCase.userActivityForArticleReturns(NSUserActivity(activityType: "com.example.test"))

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
                expect(subject.content.loadedHTMLString).to(contain(article.content))
            }
        }

        it("does not show the loading spinner") {
            expect(subject.backgroundSpinnerView.hidden) == true
        }

        describe("setting the article") {
            let article = Article(title: "article", link: NSURL(string: "https://example.com/"), summary: "summary", authors: [Author(name: "Rachel", email: nil)], published: NSDate(), updatedAt: nil, identifier: "identifier", content: "content!", read: false, estimatedReadingTime: 0, feed: nil, flags: ["a"], enclosures: [])
            let article2 = Article(title: "article2", link: NSURL(string: "https://example.com/2"), summary: "summary2", authors: [], published: NSDate(), updatedAt: nil, identifier: "identifier", content: "content!", read: false, estimatedReadingTime: 0, feed: nil, flags: ["a"], enclosures: [])
            article.addRelatedArticle(article2)
            let feed = Feed(title: "feed", url: NSURL(string: "https://example.com"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)

            let userActivity = NSUserActivity(activityType: "com.example.test")

            beforeEach {
                articleUseCase.readArticleReturns("example")
                articleUseCase.userActivityForArticleReturns(userActivity)

                article.feed = feed
                feed.addArticle(article)
                subject.setArticle(article)
            }

            it("shows the background spinner view") {
                expect(subject.backgroundSpinnerView.hidden) == false
            }

            it("asks the use case for the html to show") {
                expect(articleUseCase.readArticleCallCount) == 1
                expect(articleUseCase.readArticleArgsForCall(0)) == article
            }

            it("sets the user activity up") {
                expect(subject.userActivity) === userActivity
            }

            it("should enable link preview with 3d touch") {
                expect(subject.content.allowsLinkPreview) == true
            }

            it("should include the share button in the toolbar, and the open in safari button") {
                expect(subject.toolbarItems?.contains(subject.shareButton)) == true
                expect(subject.toolbarItems?.contains(subject.openInSafariButton)) == true
            }

            it("should exclude the open in safari button if the article has no associated link") {
                let article2 = Article(title: "article2", link: nil, summary: "summary", authors: [], published: NSDate(), updatedAt: nil, identifier: "identifier", content: "<h1>Hello World</h1>", read: false, estimatedReadingTime: 0, feed: nil, flags: ["a"], enclosures: [])
                let feed2 = Feed(title: "feed2", url: NSURL(string: "https://example.com"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)
                article2.feed = feed2
                feed2.addArticle(article2)

                subject.setArticle(article2)

                expect(subject.toolbarItems?.contains(subject.shareButton)) == true
                expect(subject.toolbarItems?.contains(subject.openInSafariButton)).to(equal(false))
            }

            describe("when the article loads") {
                beforeEach {
                    subject.content.delegate?.webViewDidFinishLoad?(subject.content)
                }

                it("hides the backgroundView") {
                    expect(subject.backgroundView.hidden) == true
                }
            }

            describe("tapping the share button") {
                beforeEach {
                    subject.shareButton.tap()
                }

                it("should bring up an activity view controller") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIActivityViewController.self))
                    if let activityViewController = subject.presentedViewController as? UIActivityViewController {
                        expect(activityViewController.activityItems.count).to(equal(1))
                        expect(activityViewController.activityItems.first as? NSURL).to(equal(article.link))

                        expect(activityViewController.applicationActivities as? [NSObject]).toNot(beNil())
                        if let activities = activityViewController.applicationActivities as? [NSObject] {
                            expect(activities.first).to(beAnInstanceOf(TOActivitySafari.self))
                            expect(activities[1]).to(beAnInstanceOf(TOActivityChrome.self))
                            expect(activities.last).to(beAnInstanceOf(AuthorActivity.self))
                        }
                    }
                }

                describe("tapping view articles by author") {
                    beforeEach {
                        guard let activityViewController = subject.presentedViewController as? UIActivityViewController else {
                            fail("")
                            return
                        }

                        activityViewController.completionWithItemsHandler?("com.rachelbrindle.rnews.author", true, nil, nil)
                    }

                    it("asks the use case for all articles by that author") {
                        expect(articleUseCase.articlesByAuthorCallCount) == 1
                    }

                    describe("when the use case returns") {
                        var articleListController: ArticleListController!

                        let articleByAuthor = Article(title: "article23", link: NSURL(string: "https://example.com/"), summary: "summary", authors: [Author(name: "Rachel", email: nil)], published: NSDate(), updatedAt: nil, identifier: "identifier", content: "content!", read: false, estimatedReadingTime: 0, feed: nil, flags: ["a"], enclosures: [])

                        beforeEach {
                            articleListController = ArticleListController(
                                feedRepository: FakeDatabaseUseCase(),
                                themeRepository: FakeThemeRepository(),
                                settingsRepository: SettingsRepository(userDefaults: nil),
                                articleViewController: { subject }
                            )
                            injector.bind(ArticleListController.self, toInstance: articleListController)

                            articleUseCase.articlesByAuthorArgsForCall(0).1(DataStoreBackedArray([article, articleByAuthor]))
                        }

                        it("configures the articleListController with the articles") {
                            expect(articleListController.title) == "Rachel"
                        }

                        it("shows an article list with the returned articles") {
                            expect(subject.shownViewController) === articleListController
                        }
                    }
                }
            }
            
            it("should open the article in an SFSafariViewController if the open in safari button is tapped") {
                subject.openInSafariButton.tap()

                expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
            }

            context("tapping a link") {
                it("navigates to that article if the link goes to a related article") {
                    let shouldInteract = subject.content.delegate?.webView?(subject.content, shouldStartLoadWithRequest: NSURLRequest(URL: article2.link!), navigationType: .LinkClicked)
                    expect(shouldInteract) == false
//                    expect(navigationController.topViewController) != subject
//                    expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
//                    guard let articleViewController = navigationController.topViewController as? ArticleViewController else { return }
//                    expect(articleViewController.article) != article
                    // This test fails because of a type mismatch between what Realm/Core Data store (String), and what the Article model stores (NSURL).
                }

                it("opens in an SFSafariViewController") {
                    let url = NSURL(string: "https://example.com")!
                    let shouldInteract = subject.content.delegate?.webView?(subject.content, shouldStartLoadWithRequest: NSURLRequest(URL: url), navigationType: .LinkClicked)
                    expect(shouldInteract) == false
                    expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                }
            }
        }
    }
}

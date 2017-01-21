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
        var themeRepository: ThemeRepository!
        var htmlViewController: HTMLViewController!
        var articleUseCase: FakeArticleUseCase!

        beforeEach {
            injector = Injector()

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            htmlViewController = HTMLViewController(themeRepository: themeRepository)
            injector.bind(kind: HTMLViewController.self, toInstance: htmlViewController)

            articleUseCase = FakeArticleUseCase()
            injector.bind(kind: ArticleUseCase.self, toInstance: articleUseCase)

            subject = injector.create(kind: ArticleViewController.self)!

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("when the view appears") {
            beforeEach {
                subject.viewDidAppear(false)
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
                themeRepository.theme = .dark
            }

            it("should update the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
            }
            it("should update the toolbar") {
                expect(subject.navigationController?.toolbar.barStyle) == themeRepository.barStyle
            }
        }

        describe("Key Commands") {
            beforeEach {
                articleUseCase.readArticleReturns("hello")
                articleUseCase.userActivityForArticleReturns(NSUserActivity(activityType: "com.example.test"))
            }

            it("can become first responder") {
                expect(subject.canBecomeFirstResponder) == true
            }

            func hasKindsOfKeyCommands(expectedCommands: [UIKeyCommand], discoveryTitles: [String]) {
                let keyCommands = subject.keyCommands
                expect(keyCommands).toNot(beNil())
                guard let commands = keyCommands else {
                    return
                }

                expect(commands.count).to(equal(expectedCommands.count))
                for (idx, cmd) in commands.enumerated() {
                    let expectedCmd = expectedCommands[idx]
                    expect(cmd.input).to(equal(expectedCmd.input))
                    expect(cmd.modifierFlags).to(equal(expectedCmd.modifierFlags))

                    let expectedTitle = discoveryTitles[idx]
                    expect(cmd.discoverabilityTitle).to(equal(expectedTitle))
                }
            }

            let article = Article(title: "article", link: URL(string: "https://example.com/article")!, summary: "summary", authors: [], published: Date(), updatedAt: nil, identifier: "identifier", content: "<h1>hi</h1>", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])

            context("when viewing an article that has a link") {
                beforeEach {
                    subject.setArticle(article, read: false, show: false)
                }

                it("should not list the next/previous article commands") {
                    let expectedCommands = [
                        UIKeyCommand(input: "r", modifierFlags: .shift, action: #selector(BlankTarget.blank)),
                        UIKeyCommand(input: "l", modifierFlags: .command, action: #selector(BlankTarget.blank)),
                        UIKeyCommand(input: "s", modifierFlags: .command, action: #selector(BlankTarget.blank)),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Toggle Read",
                        "Open Article in WebView",
                        "Open Share Sheet",
                    ]

                    hasKindsOfKeyCommands(expectedCommands: expectedCommands, discoveryTitles: expectedDiscoverabilityTitles)
                }
            }
        }

        describe("continuing from user activity") {
            let article = Article(title: "article", link: URL(string: "https://example.com/article")!, summary: "summary", authors: [], published: Date(), updatedAt: nil, identifier: "identifier", content: "<h1>hi</h1>", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: [])

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

            it("shows the content") {
                expect(htmlViewController.htmlString).to(contain(article.content))
            }
        }

        describe("setting the article") {
            let article = Article(title: "article", link: URL(string: "https://example.com/")!, summary: "summary", authors: [Author(name: "Rachel", email: nil)], published: Date(), updatedAt: nil, identifier: "identifier", content: "content!", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: ["a"])
            let article2 = Article(title: "article2", link: URL(string: "https://example.com/2")!, summary: "summary2", authors: [], published: Date(), updatedAt: nil, identifier: "identifier", content: "content!", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: ["a"])
            article.addRelatedArticle(article2)
            let feed = Feed(title: "feed", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [article], image: nil)

            let userActivity = NSUserActivity(activityType: "com.example.test")

            beforeEach {
                articleUseCase.readArticleReturns("example")
                articleUseCase.userActivityForArticleReturns(userActivity)

                article.feed = feed
                feed.addArticle(article)
                subject.setArticle(article)
            }

            it("asks the use case for the html to show") {
                expect(articleUseCase.readArticleCallCount) == 1
                expect(articleUseCase.readArticleArgsForCall(0)) == article
            }

            it("sets the user activity up") {
                expect(subject.userActivity) === userActivity
            }

            it("should include the share button in the toolbar, and the open in safari button") {
                expect(subject.toolbarItems?.contains(subject.shareButton)) == true
                expect(subject.toolbarItems?.contains(subject.openInSafariButton)) == true
            }

            it("shows the content") {
                expect(htmlViewController.htmlString).to(contain("example"))
            }

            describe("tapping the share button") {
                beforeEach {
                    subject.shareButton.tap()
                }

                it("should bring up an activity view controller") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIActivityViewController.self))
                    if let activityViewController = subject.presentedViewController as? UIActivityViewController {
                        expect(activityViewController.activityItems.count).to(equal(1))
                        expect(activityViewController.activityItems.first as? URL).to(equal(article.link))

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

                        activityViewController.completionWithItemsHandler?(UIActivityType(rawValue: "com.rachelbrindle.rnews.author"), true, nil, nil)
                    }

                    it("asks the use case for all articles by that author") {
                        expect(articleUseCase.articlesByAuthorCallCount) == 1
                    }

                    describe("when the use case returns") {
                        var articleListController: ArticleListController!

                        let articleByAuthor = Article(title: "article23", link: URL(string: "https://example.com/")!, summary: "summary", authors: [Author(name: "Rachel", email: nil)], published: Date(), updatedAt: nil, identifier: "identifier", content: "content!", read: false, synced: false, estimatedReadingTime: 0, feed: nil, flags: ["a"])

                        beforeEach {
                            articleListController = ArticleListController(
                                mainQueue: FakeOperationQueue(),
                                feedRepository: FakeDatabaseUseCase(),
                                themeRepository: themeRepository,
                                settingsRepository: SettingsRepository(userDefaults: nil),
                                articleViewController: { subject },
                                generateBookViewController: { injector.create(kind: GenerateBookViewController.self)! }
                            )
                            injector.bind(kind: ArticleListController.self, toInstance: articleListController)

                            articleUseCase.articlesByAuthorArgsForCall(0).1(DataStoreBackedArray([article, articleByAuthor]))
                        }

                        it("configures the articleListController with the articles") {
                            expect(articleListController.title) == "Rachel"
                        }

                        it("shows an article list with the returned articles") {
                            expect(subject.shown) === articleListController
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
                    articleUseCase.relatedArticlesReturns([article2])
                    let shouldOpen = htmlViewController.delegate?.openURL(url: article2.link)
                    expect(shouldOpen) == true
                    expect(navigationController.topViewController) != subject
                    expect(navigationController.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                    guard let articleViewController = navigationController.topViewController as? ArticleViewController else { return }
                    expect(articleViewController.article) === article2
                }

                it("opens in an SFSafariViewController") {
                    articleUseCase.relatedArticlesReturns([])
                    let url = URL(string: "https://example.com")!
                    let shouldOpen = htmlViewController.delegate?.openURL(url: url)
                    expect(shouldOpen) == true
                    expect(shouldOpen) == true
                    expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                }
            }

            context("3d touching a link") {
                describe("3d touching a standard link") {
                    var viewController: UIViewController?

                    beforeEach {
                        articleUseCase.relatedArticlesReturns([])

                        viewController = htmlViewController.delegate?.peekURL(url: URL(string: "https://example.com/foo")!)
                    }

                    it("presents another FindFeedViewController configured with that link") {
                        expect(viewController).to(beAnInstanceOf(SFSafariViewController.self))
                    }

                    it("replaces the navigation controller's view controller stack with just that view controller") {
                        htmlViewController.delegate?.commitViewController(viewController: viewController!)

                        expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                    }
                }
            }
        }
    }
}

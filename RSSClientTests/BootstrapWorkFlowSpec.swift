import Quick
import Nimble
import UIKit
import Ra
import rNews
import rNewsKit

class BootstrapWorkFlowSpec: QuickSpec {
    override func spec() {
        var subject: BootstrapWorkFlow!
        var window: UIWindow!
        var feedRepository: FakeFeedRepository!
        var migrationUseCase: FakeMigrationUseCase!

        beforeEach {
            window = UIWindow()
            feedRepository = FakeFeedRepository()
            migrationUseCase = FakeMigrationUseCase()

            let injector = Injector()
            injector.bind(FeedRepository.self, toInstance: feedRepository)
            injector.bind(MigrationUseCase.self, toInstance: migrationUseCase)
            injector.bind(UrlOpener.self, toInstance: FakeUrlOpener())
            let readArticleUseCase = FakeReadArticleUseCase()
            readArticleUseCase.readArticleReturns("")
            readArticleUseCase.userActivityForArticleReturns(NSUserActivity(activityType: "com.example.foo"))
            injector.bind(ReadArticleUseCase.self, toInstance: readArticleUseCase)

            subject = BootstrapWorkFlow(window: window, injector: injector)
        }

        sharedExamples("showing the feeds list") { (sharedContext: SharedExampleContext) in
            var splitViewController: UISplitViewController?

            beforeEach {
                splitViewController = window.rootViewController as? UISplitViewController
            }

            it("should have a splitViewController with a single subviewcontroller as the rootViewController") {
                expect(window.rootViewController).to(beAnInstanceOf(SplitViewController.self))
                if let splitView = window.rootViewController as? SplitViewController {
                    expect(splitView.viewControllers.count) == 2
                }
            }

            describe("the master view controller") {
                var vc: UIViewController?

                beforeEach {
                    vc = splitViewController?.viewControllers.first
                }

                it("is an instance of UINavigationController") {
                    expect(vc).to(beAnInstanceOf(UINavigationController.self))
                }

                it("has a FeedsTableViewController as the root controller") {
                    let nc = vc as? UINavigationController
                    expect(nc?.viewControllers.first).to(beAnInstanceOf(FeedsTableViewController.self))
                }

                it("shows a feeds list if a feed was specified") {
                    guard let feed = sharedContext()["feed"] as? Feed else {
                        return
                    }
                    let nc = vc as? UINavigationController
                    expect(nc?.topViewController).to(beAnInstanceOf(ArticleListController.self))
                    guard let articleListController = nc?.topViewController as? ArticleListController else { return }
                    expect(articleListController.feeds) == [feed]
                }
            }

            describe("the detail view controller") {
                var vc: UIViewController?

                beforeEach {
                    vc = splitViewController?.viewControllers.last
                }

                it("is an instance of UINavigationController") {
                    expect(vc).to(beAnInstanceOf(UINavigationController.self))
                }

                it("has an ArticleViewController as the root controller") {
                    let nc = vc as? UINavigationController
                    expect(nc?.viewControllers.first).to(beAnInstanceOf(ArticleViewController.self))
                }

                it("shows an article if an article was specified") {
                    guard let article = sharedContext()["article"] as? Article else {
                        return
                    }
                    let nc = vc as? UINavigationController
                    expect(nc?.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                    guard let articleViewController = nc?.topViewController as? ArticleViewController else { return }
                    expect(articleViewController.article) == article
                }
            }
        }

        context("on first application launch") {
            pending("it runs the user through the onboarding workflow") {}
        }

        context("on subsequent launches") {
            context("if a migration is available") {
                beforeEach {
                    feedRepository._databaseUpdateAvailable = true

                    subject.begin()
                }

                it("begins the migration use case") {
                    expect(migrationUseCase.beginWorkCallCount) == 1
                }

                it("shows a migration view controller as the root view controller") {
                    expect(window.rootViewController).to(beAnInstanceOf(MigrationViewController.self))
                }

                describe("when the migration finishes") {
                    beforeEach {
                        migrationUseCase.beginWorkArgsForCall(0)()
                    }

                    itBehavesLike("showing the feeds list")
                }
            }

            context("otherwise") {
                beforeEach {
                    feedRepository._databaseUpdateAvailable = false

                    subject.begin()
                }

                itBehavesLike("showing the feeds list")
            }

            describe("when provided with an article and a feed") {
                let feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: nil, flags: [], enclosures: [])

                context("if a migration is available") {
                    beforeEach {
                        feedRepository._databaseUpdateAvailable = true

                        subject.begin((feed, article))
                    }

                    it("begins the migration use case") {
                        expect(migrationUseCase.beginWorkCallCount) == 1
                    }

                    it("shows a migration view controller as the root view controller") {
                        expect(window.rootViewController).to(beAnInstanceOf(MigrationViewController.self))
                    }

                    describe("when the migration finishes") {
                        beforeEach {
                            migrationUseCase.beginWorkArgsForCall(0)()
                        }

                        itBehavesLike("showing the feeds list") {
                            ["feed": feed, "article": article]
                        }
                    }
                }

                context("otherwise") {
                    beforeEach {
                        feedRepository._databaseUpdateAvailable = false

                        subject.begin((feed, article))
                    }

                    itBehavesLike("showing the feeds list") {
                        ["feed": feed, "article": article]
                    }
                }
            }
        }
    }
}

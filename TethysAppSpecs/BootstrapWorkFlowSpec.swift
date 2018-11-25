import Quick
import Nimble
import UIKit
import Tethys
import TethysKit

class BootstrapWorkFlowSpec: QuickSpec {
    override func spec() {
        var subject: BootstrapWorkFlow!
        var window: UIWindow!
        var feedRepository: FakeDatabaseUseCase!
        var migrationUseCase: FakeMigrationUseCase!
        var splitViewController: SplitViewController!

        beforeEach {
            window = UIWindow()
            feedRepository = FakeDatabaseUseCase()
            migrationUseCase = FakeMigrationUseCase()

            splitViewController = splitViewControllerFactory()

            let articleUseCase = FakeArticleUseCase()
            articleUseCase.readArticleReturns("")

            subject = BootstrapWorkFlow(
                window: window,
                feedRepository: feedRepository,
                migrationUseCase: migrationUseCase,
                splitViewController: splitViewController,
                migrationViewController: { migrationViewControllerFactory() },
                feedsTableViewController: {
                    feedsTableViewControllerFactory(
                        articleListController: { feed in
                            articleListControllerFactory(feed: feed, articleViewController: { article in
                                return articleViewControllerFactory(article: article, articleUseCase: articleUseCase)
                            })
                        }
                    )
                },
                blankViewController: { blankViewControllerFactory() }
            )
        }

        func itBehavesLikeItHasAFeedsList(feed: Feed? = nil, article: Article? = nil) {
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

                if feed != nil {
                    it("shows the list of articles for the feed") {
                        let nc = vc as? UINavigationController
                        expect(nc?.topViewController).to(beAnInstanceOf(ArticleListController.self))
                        guard let articleListController = nc?.topViewController as? ArticleListController else { return }
                        expect(articleListController.feed) == feed
                    }
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

                if article != nil {
                    it("shows an ArticleViewController as the root controller") {
                        let nc = vc as? UINavigationController
                        expect(nc?.viewControllers.first).to(beAnInstanceOf(ArticleViewController.self))
                    }

                    it("shows the article") {
                        let nc = vc as? UINavigationController
                        expect(nc?.topViewController).to(beAnInstanceOf(ArticleViewController.self))
                        guard let articleViewController = nc?.topViewController as? ArticleViewController else { return }
                        expect(articleViewController.article) == article
                    }
                } else {
                    it("shows a view controller configured with the theme repository") {
                        let nc = vc as? UINavigationController
                        expect(nc?.visibleViewController).to(beAnInstanceOf(BlankViewController.self))
                    }
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

                    itBehavesLikeItHasAFeedsList()
                }
            }

            context("otherwise") {
                beforeEach {
                    feedRepository._databaseUpdateAvailable = false

                    subject.begin()
                }

                itBehavesLikeItHasAFeedsList()
            }

            describe("when provided with an article and a feed") {
                let feed = Feed(title: "", url: URL(string: "https://example.com")!, summary: "", tags: [], articles: [], image: nil)
                let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "", content: "", read: false, synced: false, feed: nil, flags: [])

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

                        itBehavesLikeItHasAFeedsList(feed: feed, article: article)
                    }
                }

                context("otherwise") {
                    beforeEach {
                        feedRepository._databaseUpdateAvailable = false

                        subject.begin((feed, article))
                    }

                    itBehavesLikeItHasAFeedsList(feed: feed, article: article)
                }
            }
        }
    }
}

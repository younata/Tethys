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
        var injector: Injector!

        beforeEach {
            window = UIWindow()
            feedRepository = FakeFeedRepository()
            migrationUseCase = FakeMigrationUseCase()

            injector = Injector(module: SpecInjectorModule())
            injector.bind(FeedRepository.self, toInstance: feedRepository)
            injector.bind(MigrationUseCase.self, toInstance: migrationUseCase)

            subject = BootstrapWorkFlow(window: window, injector: injector)
        }

        sharedExamples("showing the feeds list") {
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

            describe("master view controller") {
                var vc: UIViewController?

                beforeEach {
                    vc = splitViewController?.viewControllers.first
                }

                it("should be an instance of UINavigationController") {
                    expect(vc).to(beAnInstanceOf(UINavigationController.self))
                }

                it("should have a FeedsTableViewController as the root controller") {
                    let nc = vc as? UINavigationController
                    expect(nc?.viewControllers.first).to(beAnInstanceOf(FeedsTableViewController.self))
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
        }
    }
}

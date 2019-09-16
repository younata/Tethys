import Quick
import Nimble
import Tethys
import TethysKit
import CoreSpotlight
import Result
import Swinject


class AppDelegateSpec: QuickSpec {
    override func spec() {
        var subject: AppDelegate! = nil

        let application = UIApplication.shared
        var container: Container! = nil

        var feedService: FakeFeedService! = nil

        var analytics: FakeAnalytics! = nil
        var importUseCase: FakeImportUseCase! = nil

        beforeEach {
            subject = AppDelegate()

            container = Container()

            container.register(OperationQueue.self, name: kMainQueue) { _ in FakeOperationQueue() }
            container.register(OperationQueue.self, name: kBackgroundQueue) { _ in FakeOperationQueue() }

            feedService = FakeFeedService()
            container.register(FeedService.self) { _ in feedService }

            analytics = FakeAnalytics()
            container.register(Analytics.self) { _ in analytics }

            importUseCase = FakeImportUseCase()
            container.register(ImportUseCase.self) { _ in importUseCase }

            container.register(SplitViewController.self) { _ in splitViewControllerFactory() }
            container.register(FeedListController.self) { _ in feedListControllerFactory() }

            subject.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

            subject.container = container
        }

        describe("-application:didFinishLaunchingWithOptions:") {
            it("tells analytics that the app was launched") {
                _ = subject.application(application, didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey(rawValue: "test"): true])
                expect(analytics.logEventCallCount) == 1
                if (analytics.logEventCallCount > 0) {
                    expect(analytics.logEventArgsForCall(0).0) == "SessionBegan"
                    expect(analytics.logEventArgsForCall(0).1).to(beNil())
                }
            }

            describe("window view controllers") {
                var splitViewController: UISplitViewController! = nil

                beforeEach {
                    _ = subject.application(application, didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey(rawValue: "test"): true])

                    splitViewController = subject.window!.rootViewController as? UISplitViewController
                }

                it("should have a splitViewController with a single subviewcontroller as the rootViewController") {
                    expect(subject.window!.rootViewController).to(beAnInstanceOf(SplitViewController.self))
                    if let splitView = subject.window?.rootViewController as? SplitViewController {
                        expect(splitView.viewControllers.count).to(equal(2))
                    }
                }

                describe("master view controller") {
                    var vc: UIViewController! = nil

                    beforeEach {
                        vc = splitViewController.viewControllers[0] as UIViewController
                    }

                    it("is an instance of UINavigationController") {
                        expect(vc).to(beAnInstanceOf(UINavigationController.self))
                    }

                    it("has a FeedListController as the root controller") {
                        let nc = vc as! UINavigationController
                        expect(nc.viewControllers.first).to(beAnInstanceOf(FeedListController.self))
                    }
                }

                describe("the detail view controller") {
                    it("shows a regular view controller inside of a navigation controller") {
                        expect(splitViewController.viewControllers[1]).to(beAKindOf(UINavigationController.self))
                        expect((splitViewController.viewControllers[1] as? UINavigationController)?.viewControllers).to(haveCount(1))
                    }
                }
            }
        }

        describe("being told to open a url") {
            let url = URL(fileURLWithPath: "/ooga/booga")
            var receivedValue: Bool? = nil
            beforeEach {
                receivedValue = subject.application(application, open: url, options: [:])
            }

            it("returns true") {
                expect(receivedValue) == true
            }

            it("tells the system to import the url") {
                expect(importUseCase.scanForImportableCalls).to(haveCount(1))
                expect(importUseCase.scanForImportableCalls.last) == url
            }

            describe("if an opml is found at that url") {
                beforeEach {
                    importUseCase.scanForImportablePromises.last?.resolve(.opml(url, 1))
                }

                it("tries to import the url") {
                    expect(importUseCase.importItemCalls).to(haveCount(1))
                    expect(importUseCase.importItemCalls.last) == url
                }
            }

            describe("otherwise") {
                beforeEach {
                    importUseCase.scanForImportablePromises.last?.resolve(.none(url))
                }

                it("does not try to import the url") {
                    expect(importUseCase.importItemCalls).to(beEmpty())
                }
            }
        }

        describe("Quick actions") {
            var completedAction: Bool? = nil
            beforeEach {
                _ = subject.application(application, didFinishLaunchingWithOptions: [UIApplication.LaunchOptionsKey(rawValue: "test"): true, UIApplication.LaunchOptionsKey.shortcutItem: ""])

                completedAction = nil
            }

            describe("when the 'Add New Feed' action is selected") {
                beforeEach {
                    let shortCut = UIApplicationShortcutItem(type: "com.rachelbrindle.rssclient.newfeed", localizedTitle: "Add New Feed")

                    subject.application(application, performActionFor: shortCut) {completed in
                        completedAction = completed
                    }
                }

                it("opens an add feed from web window when the 'Add New Feed' action is selected") {
                    expect(completedAction) == true
                    let navController = (subject.window?.rootViewController as? UISplitViewController)?.viewControllers.first as? UINavigationController
                    expect((navController?.visibleViewController as? UINavigationController)?.visibleViewController).to(beAKindOf(FindFeedViewController.self))
                }

                it("tells analytics to log that the user used quick actions to add a new feed") {
                    expect(analytics.logEventCallCount) == 1
                    if (analytics.logEventCallCount > 0) {
                        expect(analytics.logEventArgsForCall(0).0) == "QuickActionUsed"
                        expect(analytics.logEventArgsForCall(0).1) == ["kind": "Add New Feed"]
                    }
                }
            }
        }
    }
}

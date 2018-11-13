import Quick
import Nimble
import Tethys
import TethysKit
import CoreSpotlight
import Result
import Swinject

fileprivate class FakeBackgroundFetchHandler: BackgroundFetchHandler {
    fileprivate var performFetchCalled = false
    fileprivate func performFetch(_ notificationHandler: NotificationHandler, notificationSource: LocalNotificationSource, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        performFetchCalled = true
    }

    fileprivate var handleEventsCalled = false
}

class AppDelegateSpec: QuickSpec {
    override func spec() {
        var subject: AppDelegate! = nil

        let application = UIApplication.shared
        var container: Container! = nil

        var dataUseCase: FakeDatabaseUseCase! = nil

        var notificationHandler: FakeNotificationHandler! = nil
        var backgroundFetchHandler: FakeBackgroundFetchHandler! = nil
        var analytics: FakeAnalytics! = nil
        var importUseCase: FakeImportUseCase! = nil

        beforeEach {
            subject = AppDelegate()

            container = Container()

            container.register(OperationQueue.self, name: kMainQueue) { _ in FakeOperationQueue() }
            container.register(OperationQueue.self, name: kBackgroundQueue) { _ in FakeOperationQueue() }

            dataUseCase = FakeDatabaseUseCase()
            container.register(DatabaseUseCase.self) { _ in dataUseCase }

            container.register(MigrationUseCase.self) { _ in FakeMigrationUseCase() }

            analytics = FakeAnalytics()
            container.register(Analytics.self) { _ in analytics }

            notificationHandler = FakeNotificationHandler()
            container.register(NotificationHandler.self) { _ in notificationHandler }

            backgroundFetchHandler = FakeBackgroundFetchHandler()
            container.register(BackgroundFetchHandler.self) { _ in backgroundFetchHandler }

            importUseCase = FakeImportUseCase()
            container.register(ImportUseCase.self) { _ in importUseCase }

            container.register(SplitViewController.self) { _ in splitViewControllerFactory() }
            container.register(Bootstrapper.self) { _, window, splitView in
                bootstrapWorkFlowFactory(window: window, splitViewController: splitView)
            }

            subject.window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

            subject.container = container
        }

        describe("-application:didFinishLaunchingWithOptions:") {
            it("should enable notifications") {
                _ = subject.application(application, didFinishLaunchingWithOptions: [UIApplicationLaunchOptionsKey(rawValue: "test"): true])

                expect(notificationHandler.enableNotificationsCalls).to(haveCount(1))
            }

            it("tells analytics that the app was launched") {
                _ = subject.application(application, didFinishLaunchingWithOptions: [UIApplicationLaunchOptionsKey(rawValue: "test"): true])
                expect(analytics.logEventCallCount) == 1
                if (analytics.logEventCallCount > 0) {
                    expect(analytics.logEventArgsForCall(0).0) == "SessionBegan"
                    expect(analytics.logEventArgsForCall(0).1).to(beNil())
                }
            }

            it("should add the UIApplication object to the dataWriter's subscribers") {
                _ = subject.application(application, didFinishLaunchingWithOptions: [UIApplicationLaunchOptionsKey(rawValue: "test"): true])

                var applicationInSubscribers = false
                for subscriber in dataUseCase.subscribers.allObjects {
                    if subscriber is UIApplication {
                        applicationInSubscribers = true
                        break
                    }
                }
                expect(applicationInSubscribers) == true
            }

            describe("window view controllers") {
                var splitViewController: UISplitViewController! = nil

                beforeEach {
                    _ = subject.application(application, didFinishLaunchingWithOptions: [UIApplicationLaunchOptionsKey(rawValue: "test"): true])

                    splitViewController = subject.window!.rootViewController as! UISplitViewController
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

                    it("should be an instance of UINavigationController") {
                        expect(vc).to(beAnInstanceOf(UINavigationController.self))
                    }

                    it("should have a FeedsTableViewController as the root controller") {
                        let nc = vc as! UINavigationController
                        expect(nc.viewControllers.first).to(beAnInstanceOf(FeedsTableViewController.self))
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
                _ = subject.application(application, didFinishLaunchingWithOptions: [UIApplicationLaunchOptionsKey(rawValue: "test"): true, UIApplicationLaunchOptionsKey.shortcutItem: ""])

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
                    expect(navController?.visibleViewController).to(beAKindOf(UINavigationController.self))
                    let viewController = (navController?.visibleViewController as? UINavigationController)?.topViewController
                    expect(viewController).to(beAKindOf(FindFeedViewController.self))
                }

                it("tells analytics to log that the user used quick actions to add a new feed") {
                    expect(analytics.logEventCallCount) == 1
                    if (analytics.logEventCallCount > 0) {
                        expect(analytics.logEventArgsForCall(0).0) == "QuickActionUsed"
                        expect(analytics.logEventArgsForCall(0).1) == ["kind": "Add New Feed"]
                    }
                }
            }

            describe("selecting a 'View Feed' action") {
                let feed = Feed(title: "title", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feed")
                let article = Article(title: "title", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "identifier", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: feed, flags: [])
                feed.addArticle(article)

                context("when the userInfo is properly set") {
                    beforeEach {
                        let shortCut = UIApplicationShortcutItem(type: "com.rachelbrindle.rssclient.viewfeed",
                                                                 localizedTitle: feed.displayTitle,
                                                                 localizedSubtitle: nil,
                                                                 icon: nil,
                                                                 userInfo: ["feed": feed.title])

                        subject.application(application, performActionFor: shortCut) {completed in
                            completedAction = completed
                        }
                    }

                    it("asks the dataUseCase for the feeds") {
                        expect(dataUseCase.feedsPromises.count) == 1
                    }

                    describe("when the promise succeeds") {
                        context("and the selected feed is in the list") {
                            beforeEach {
                                dataUseCase.feedsPromises.last?.resolve(.success([feed]))
                            }

                            it("opens an article list for the selected feed") {
                                expect(completedAction) == true

                                let navController = (subject.window?.rootViewController as? UISplitViewController)?.viewControllers.first as? UINavigationController
                                expect(navController?.visibleViewController).to(beAKindOf(ArticleListController.self))
                                let articleController = navController?.visibleViewController as? ArticleListController
                                expect(articleController?.feed) == feed
                            }

                            it("tells analytics to log that the user used quick actions to add a new feed") {
                                expect(analytics.logEventCallCount) == 1
                                if (analytics.logEventCallCount > 0) {
                                    expect(analytics.logEventArgsForCall(0).0) == "QuickActionUsed"
                                    expect(analytics.logEventArgsForCall(0).1) == ["kind": "View Feed"]
                                }
                            }
                        }

                        context("and the selected feed is not in the list") {
                            beforeEach {
                                dataUseCase.feedsPromises.last?.resolve(.success([]))
                            }

                            it("does nothing and returns false") {
                                expect(completedAction) == false
                            }
                        }
                    }

                    describe("when the promise fails") {
                        beforeEach {
                            dataUseCase.feedsPromises.last?.resolve(.failure(.unknown))
                        }

                        it("does nothing and returns false") {
                            expect(completedAction) == false
                        }
                    }
                }

                context("when the userinfo was not set") {
                    beforeEach {
                        let shortCut = UIApplicationShortcutItem(type: "com.rachelbrindle.rssclient.viewfeed",
                                                                 localizedTitle: feed.displayTitle)

                        subject.application(application, performActionFor: shortCut) {completed in
                            completedAction = completed
                        }
                    }

                    it("asks the dataUseCase for the feeds") {
                        expect(dataUseCase.feedsPromises.count) == 1
                    }

                    describe("when the promise succeeds") {
                        context("and the selected feed is in the list") {
                            beforeEach {
                                dataUseCase.feedsPromises.last?.resolve(.success([feed]))
                            }

                            it("opens an article list for the selected feed") {
                                expect(completedAction) == true

                                let navController = (subject.window?.rootViewController as? UISplitViewController)?.viewControllers.first as? UINavigationController
                                expect(navController?.visibleViewController).to(beAKindOf(ArticleListController.self))
                                let articleController = navController?.visibleViewController as? ArticleListController
                                expect(articleController?.feed) == feed
                            }

                            it("tells analytics to log that the user used quick actions to add a new feed") {
                                expect(analytics.logEventCallCount) == 1
                                if (analytics.logEventCallCount > 0) {
                                    expect(analytics.logEventArgsForCall(0).0) == "QuickActionUsed"
                                    expect(analytics.logEventArgsForCall(0).1) == ["kind": "View Feed"]
                                }
                            }
                        }

                        context("and the selected feed is not in the list") {
                            beforeEach {
                                dataUseCase.feedsPromises.last?.resolve(.success([]))
                            }

                            it("does nothing and returns false") {
                                expect(completedAction) == false
                            }
                        }
                    }

                    describe("when the promise fails") {
                        beforeEach {
                            dataUseCase.feedsPromises.last?.resolve(.failure(.unknown))
                        }

                        it("does nothing and returns false") {
                            expect(completedAction) == false
                        }
                    }
                }
            }
        }

        describe("Local notifications") {
            describe("receiving notifications") {
                beforeEach {
                    subject.application(UIApplication.shared, didReceive: UILocalNotification())
                }
                it("should forward to the notification handler") {

                    expect(notificationHandler.handleLocalNotificationCalls).to(haveCount(1))
                    expect(notificationHandler.handleActionCalls).to(beEmpty())
                }
            }
            describe("handling notification actions") {
                var completionHandlerCalled: Bool = false
                beforeEach {
                    completionHandlerCalled = false
                    subject.application(UIApplication.shared, handleActionWithIdentifier: "read", for: UILocalNotification()) {
                        completionHandlerCalled = true
                    }
                }
                it("should forward to the notification handler") {
                    expect(notificationHandler.handleActionCalls).to(haveCount(1))
                    expect(notificationHandler.handleActionCalls.last?.0).to(equal("read"))
                }
                it("should call the completionHandler") {
                    expect(completionHandlerCalled) == true
                }
            }
        }

        describe("background fetch") {
            beforeEach {
                subject.application(UIApplication.shared) {res in }
            }

            it("should forward the call to the backgroundFetchHandler") {
                expect(backgroundFetchHandler.performFetchCalled) == true
            }
        }

        describe("user activities") {
            var responderArray: [UIResponder] = []
            var article: Article! = nil

            beforeEach {
                let feed = Feed(title: "title", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feed")
                article = Article(title: "title", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "identifier", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: feed, flags: [])
                feed.addArticle(article)
                _ = subject.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
            }

            describe("normal user activities") {
                beforeEach {
                    let activity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
                    activity.userInfo = [
                        "feed": "feed",
                        "article": "identifier",
                    ]
                    expect(subject.application(UIApplication.shared, continue: activity) {responders in
                        responderArray = responders as? [UIResponder] ?? []
                    }) == true
                }
                
                it("should not set the responderArray") {
                    expect(responderArray).to(beEmpty())
                }
            }
            
            describe("searchable user activities") {
                beforeEach {
                    let activity = NSUserActivity(activityType: CSSearchableItemActionType)
                    activity.userInfo = [CSSearchableItemActivityIdentifier: "identifier"]
                    expect(subject.application(UIApplication.shared, continue: activity) {responders in
                        responderArray = responders as? [UIResponder] ?? []
                    }) == true
                }
                
                it("should not set the responderArray") {
                    expect(responderArray).to(beEmpty())
                }
            }
        }
    }
}

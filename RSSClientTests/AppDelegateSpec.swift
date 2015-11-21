import Quick
import Nimble
import Ra
import rNews
import rNewsKit
import CoreSpotlight

private class FakeNotificationHandler: NotificationHandler {
    private var didEnableNotifications = false
    private override func enableNotifications(notificationSource: LocalNotificationSource) {
        didEnableNotifications = true
    }

    private var lastNotificationHandled: UILocalNotification? = nil
    private override func handleLocalNotification(notification: UILocalNotification, window: UIWindow) {
        lastNotificationHandled = notification
    }

    private var lastNotificationActionIdentifier: String? = nil
    private override func handleAction(identifier: String?, notification: UILocalNotification) {
        lastNotificationHandled = notification
        lastNotificationActionIdentifier = identifier
    }
}

private class FakeBackgroundFetchHandler: BackgroundFetchHandler {
    private var performFetchCalled = false
    private override func performFetch(notificationHandler: NotificationHandler, notificationSource: LocalNotificationSource, completionHandler: (UIBackgroundFetchResult) -> Void) {
        performFetchCalled = true
    }

    private var handleEventsCalled = false
}

class AppDelegateSpec: QuickSpec {
    override func spec() {
        var subject: AppDelegate! = nil
        
        let application = UIApplication.sharedApplication()
        var injector : Ra.Injector! = nil

        var dataReadWriter: FakeDataReadWriter! = nil

        var notificationHandler: FakeNotificationHandler! = nil
        var backgroundFetchHandler: FakeBackgroundFetchHandler! = nil
        
        beforeEach {
            subject = AppDelegate()

            injector = Ra.Injector()

            dataReadWriter = FakeDataReadWriter()
            injector.bind(DataRetriever.self, to: dataReadWriter)
            injector.bind(DataWriter.self, to: dataReadWriter)

            notificationHandler = FakeNotificationHandler()
            injector.bind(NotificationHandler.self, to: notificationHandler)

            backgroundFetchHandler = FakeBackgroundFetchHandler()
            injector.bind(BackgroundFetchHandler.self, to: backgroundFetchHandler)

            subject.anInjector = injector
            subject.window = UIWindow(frame: CGRectMake(0, 0, 320, 480))
        }
        
        describe("-application:didFinishLaunchingWithOptions:") {
            beforeEach {
                subject.application(application, didFinishLaunchingWithOptions: ["test": true])
            }

            it("should enable notifications") {
                expect(notificationHandler.didEnableNotifications).to(beTruthy())
            }

            it("should add the UIApplication object to the dataWriter's subscribers") {
                var applicationInSubscribers = false
                for subscriber in dataReadWriter.subscribers.allObjects {
                    if subscriber is UIApplication {
                        applicationInSubscribers = true
                        break
                    }
                }
                expect(applicationInSubscribers).to(beTruthy())
            }

            describe("window view controllers") {
                var splitViewController: UISplitViewController! = nil
                
                beforeEach {
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

        if #available(iOS 9.0, *) {
            describe("Quick actions") {
                var completedAction: Bool? = nil
                beforeEach {
                    subject.application(application, didFinishLaunchingWithOptions: ["test": true])

                    completedAction = nil
                }

                it("opens an add feed from web window when the 'Add New Feed' action is selected") {
                    let shortCut = UIApplicationShortcutItem(type: "com.rachelbrindle.RSSClient.newfeed", localizedTitle: "Add New Feed")

                    subject.application(application, performActionForShortcutItem: shortCut) {completed in
                        completedAction = completed
                    }

                    expect(completedAction).to(beTruthy())
                    let navController = (subject.window?.rootViewController as? UISplitViewController)?.viewControllers.first as? UINavigationController
                    expect(navController?.visibleViewController).to(beAKindOf(UINavigationController.self))
                    let viewController = (navController?.visibleViewController as? UINavigationController)?.topViewController
                    expect(viewController).to(beAKindOf(FindFeedViewController.self))
                }
            }
        }

        describe("Local notifications") {
            describe("receiving notifications") {
                beforeEach {
                    subject.application(UIApplication.sharedApplication(), didReceiveLocalNotification: UILocalNotification())
                }
                it("should forward to the notification handler") {
                    expect(notificationHandler.lastNotificationHandled).toNot(beNil())
                    expect(notificationHandler.lastNotificationActionIdentifier).to(beNil())
                }
            }
            describe("handling notification actions") {
                var completionHandlerCalled: Bool = false
                beforeEach {
                    completionHandlerCalled = false
                    subject.application(UIApplication.sharedApplication(), handleActionWithIdentifier: "read", forLocalNotification: UILocalNotification()) {
                        completionHandlerCalled = true
                    }
                }
                it("should forward to the notification handler") {
                    expect(notificationHandler.lastNotificationHandled).toNot(beNil())
                    expect(notificationHandler.lastNotificationActionIdentifier).to(equal("read"))
                }
                it("should call the completionHandler") {
                    expect(completionHandlerCalled).to(beTruthy())
                }
            }
        }

        describe("background fetch") {
            beforeEach {
                subject.application(UIApplication.sharedApplication()) {res in }
            }

            it("should forward the call to the backgroundFetchHandler") {
                expect(backgroundFetchHandler.performFetchCalled).to(beTruthy())
            }
        }

        describe("user activities") {
            var responderArray: [UIResponder] = []
            var article: Article! = nil

            beforeEach {
                let feed = Feed(title: "title", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feed")
                article = Article(title: "title", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "identifier", content: "", read: false, feed: feed, flags: [], enclosures: [])
                feed.addArticle(article)
                dataReadWriter.feedsList = [feed]
                subject.application(UIApplication.sharedApplication(), didFinishLaunchingWithOptions: nil)
            }

            describe("normal user activities") {
                beforeEach {
                    let activity = NSUserActivity(activityType: "com.rachelbrindle.rssclient.article")
                    activity.userInfo = [
                        "feed": "feed",
                        "article": "identifier",
                    ]
                    expect(subject.application(UIApplication.sharedApplication(), continueUserActivity: activity) {responders in
                        responderArray = responders as? [UIResponder] ?? []
                    }).to(beTruthy())
                }

                it("should not set the responderArray") {
                    expect(responderArray).to(beEmpty())
                }

                it("should show the article") {
                    if let item = responderArray.first as? ArticleViewController {
                        expect(item.article).to(equal(article))
                    }
                }
            }

            describe("searchable user activities (iOS 9)") {
                beforeEach {
                    if #available(iOS 9.0, *) {
                        let activity = NSUserActivity(activityType: CSSearchableItemActionType)
                        activity.userInfo = [CSSearchableItemActivityIdentifier: "identifier"]
                        expect(subject.application(UIApplication.sharedApplication(), continueUserActivity: activity) {responders in
                            responderArray = responders as? [UIResponder] ?? []
                        }).to(beTruthy())
                    }
                }

                it("should not set the responderArray") {
                    guard #available(iOS 9.0, *) else {
                        return
                    }
                    expect(responderArray).to(beEmpty())
                }

                it("should show the article") {
                    guard #available(iOS 9.0, *) else {
                        return
                    }
                    if let item = responderArray.first as? ArticleViewController {
                        expect(item.article).to(equal(article))
                    }
                }
            }
        }
    }
}

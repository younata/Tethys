import Quick
import Nimble
import Ra
import rNews

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
}

class AppDelegateSpec: QuickSpec {
    override func spec() {
        var subject: AppDelegate! = nil
        
        let application = UIApplication.sharedApplication()
        var injector : Ra.Injector! = nil

        var notificationHandler: FakeNotificationHandler! = nil
        var backgroundFetchHandler: FakeBackgroundFetchHandler! = nil
        
        beforeEach {
            subject = AppDelegate()

            injector = Ra.Injector()
            let dataManager = DataManagerMock()
            injector.bind(DataManager.self) {
                dataManager
            }
            injector.bind(kBackgroundManagedObjectContext, to: dataManager.backgroundObjectContext)

            notificationHandler = FakeNotificationHandler()
            injector.bind(NotificationHandler.self, to: notificationHandler)

            backgroundFetchHandler = FakeBackgroundFetchHandler()
            injector.bind(BackgroundFetchHandler.self, to: backgroundFetchHandler)

            subject.anInjector = injector
            subject.window = UIWindow(frame: CGRectMake(0, 0, 320, 480))
            // Apparently, calling "-makeKeyAndVisible" on a window in test will cause a crash.
        }
        
        describe("-application:didFinishLaunchingWithOptions:") {
            beforeEach {
                subject.application(application, didFinishLaunchingWithOptions: nil)
                return
            }

            it("should enable notifications") {
                expect(notificationHandler.didEnableNotifications).to(beTruthy())
            }

            describe("window view controllers") {
                var splitViewController: UISplitViewController! = nil
                
                beforeEach {
                    splitViewController = subject.window!.rootViewController as! UISplitViewController
                }

                it("should have a splitViewController as the rootViewController") {
                    expect(subject.window!.rootViewController).to(beAnInstanceOf(UISplitViewController.self))
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

                describe("detail view controller") {
                    var vc: UIViewController! = nil
                    
                    beforeEach {
                        vc = splitViewController.viewControllers[1]
                    }
                    
                    it("should be an instance of UINavigationController") {
                        expect(vc).to(beAnInstanceOf(UINavigationController.self))
                    }
                    
                    it("should have an ArticleViewController as the root controller") {
                        let nc = vc as! UINavigationController
                        expect(nc.viewControllers.first).to(beAnInstanceOf(ArticleViewController.self))
                    }
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
    }
}

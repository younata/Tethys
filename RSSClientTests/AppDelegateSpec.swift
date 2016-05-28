import Quick
import Nimble
import Ra
import rNews
import rNewsKit
import CoreSpotlight
import Result

private class FakeBackgroundFetchHandler: BackgroundFetchHandler {
    private var performFetchCalled = false
    private func performFetch(notificationHandler: NotificationHandler, notificationSource: LocalNotificationSource, completionHandler: (UIBackgroundFetchResult) -> Void) {
        performFetchCalled = true
    }

    private var handleEventsCalled = false
}

class AppDelegateSpec: QuickSpec {
    override func spec() {
        var subject: AppDelegate! = nil
        
        let application = UIApplication.sharedApplication()
        var injector: Ra.Injector! = nil

        var dataUseCase: FakeDatabaseUseCase! = nil

        var notificationHandler: FakeNotificationHandler! = nil
        var backgroundFetchHandler: FakeBackgroundFetchHandler! = nil
        
        beforeEach {
            subject = AppDelegate()

            injector = Ra.Injector()

            injector.bind(kMainQueue, toInstance: FakeOperationQueue())
            injector.bind(kBackgroundQueue, toInstance: FakeOperationQueue())

            dataUseCase = FakeDatabaseUseCase()
            injector.bind(DatabaseUseCase.self, toInstance: dataUseCase)

            injector.bind(MigrationUseCase.self, toInstance: FakeMigrationUseCase())
            injector.bind(ImportUseCase.self, toInstance: FakeImportUseCase())

            InjectorModule().configureInjector(injector)

            notificationHandler = FakeNotificationHandler()
            injector.bind(NotificationHandler.self, toInstance: notificationHandler)

            backgroundFetchHandler = FakeBackgroundFetchHandler()
            injector.bind(BackgroundFetchHandler.self, toInstance: backgroundFetchHandler)


            subject.anInjector = injector
            subject.window = UIWindow(frame: CGRectMake(0, 0, 320, 480))
        }
        
        describe("-application:didFinishLaunchingWithOptions:") {
            it("should on first launch add a query feed for all unread articles") {
                let userDefaults = NSUserDefaults.standardUserDefaults()
                userDefaults.removeObjectForKey("firstLaunch")

                subject.application(application, didFinishLaunchingWithOptions: ["test": true])

                expect(dataUseCase.didCreateFeed) == true

                let feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                dataUseCase.newFeedCallback(feed)

                expect(feed.title).to(equal("All Unread"))
                expect(feed.summary).to(equal("All unread articles"))
                expect(feed.query).to(equal("function(article) {\n    return !article.read;\n}"))
                expect(userDefaults.boolForKey("firstLaunch")) == true

            }

            it("should not add a query feed on any subsequent launches") {
                let userDefaults = NSUserDefaults.standardUserDefaults()
                userDefaults.setBool(true, forKey: "firstLaunch")

                subject.application(application, didFinishLaunchingWithOptions: ["test": true])

                expect(dataUseCase.didCreateFeed) == false
            }

            it("should enable notifications") {
                subject.application(application, didFinishLaunchingWithOptions: ["test": true])

                expect(notificationHandler.enableNotificationsCallCount) == 1
            }

            it("should add the UIApplication object to the dataWriter's subscribers") {
                subject.application(application, didFinishLaunchingWithOptions: ["test": true])

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
                    subject.application(application, didFinishLaunchingWithOptions: ["test": true])

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

                    expect(completedAction) == true
                    let navController = (subject.window?.rootViewController as? UISplitViewController)?.viewControllers.first as? UINavigationController
                    expect(navController?.visibleViewController).to(beAKindOf(UINavigationController.self))
                    let viewController = (navController?.visibleViewController as? UINavigationController)?.topViewController
                    expect(viewController).to(beAKindOf(FindFeedViewController.self))
                }

                describe("selecting a 'View Feed' action") {
                    let feed = Feed(title: "title", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feed")
                    let article = Article(title: "title", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "identifier", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [], enclosures: [])
                    feed.addArticle(article)

                    beforeEach {
                        let shortCut = UIApplicationShortcutItem(type: "com.rachelbrindle.RSSClient.viewfeed",
                            localizedTitle: feed.displayTitle,
                            localizedSubtitle: nil,
                            icon: nil,
                            userInfo: ["feed": feed.title])

                        subject.application(application, performActionForShortcutItem: shortCut) {completed in
                            completedAction = completed
                        }
                    }

                    it("asks the dataUseCase for the feeds") {
                        expect(dataUseCase.feedsPromises.count) == 1
                    }

                    describe("when the promise succeeds") {
                        context("and the selected feed is in the list") {
                            beforeEach {
                                dataUseCase.feedsPromises.last?.resolve(.Success([feed]))
                            }

                            it("opens an article list for the selected feed") {
                                expect(completedAction) == true

                                let navController = (subject.window?.rootViewController as? UISplitViewController)?.viewControllers.first as? UINavigationController
                                expect(navController?.visibleViewController).to(beAKindOf(ArticleListController.self))
                                let articleController = navController?.visibleViewController as? ArticleListController
                                expect(articleController?.feeds).to(equal([feed]))
                            }
                        }

                        context("and the selected feed is not in the list") {
                            beforeEach {
                                dataUseCase.feedsPromises.last?.resolve(.Success([]))
                            }

                            it("does nothing and returns false") {
                                expect(completedAction) == false
                            }
                        }
                    }

                    describe("when the promise fails") {
                        beforeEach {
                            dataUseCase.feedsPromises.last?.resolve(.Failure(.Unknown))
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
                    subject.application(UIApplication.sharedApplication(), didReceiveLocalNotification: UILocalNotification())
                }
                it("should forward to the notification handler") {
                    expect(notificationHandler.handleLocalNotificationCallCount) == 1
                    expect(notificationHandler.handleActionCallCount) == 0
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
                    expect(notificationHandler.handleActionCallCount) == 1
                    expect(notificationHandler.handleActionArgsForCall(0).0).to(equal("read"))
                }
                it("should call the completionHandler") {
                    expect(completionHandlerCalled) == true
                }
            }
        }

        describe("background fetch") {
            beforeEach {
                subject.application(UIApplication.sharedApplication()) {res in }
            }

            it("should forward the call to the backgroundFetchHandler") {
                expect(backgroundFetchHandler.performFetchCalled) == true
            }
        }

        describe("user activities") {
            var responderArray: [UIResponder] = []
            var article: Article! = nil

            beforeEach {
                let feed = Feed(title: "title", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feed")
                article = Article(title: "title", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "identifier", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [], enclosures: [])
                feed.addArticle(article)
//                dataRepository.feedsList = [feed]
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
                    }) == true
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
                        }) == true
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

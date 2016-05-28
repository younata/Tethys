import Quick
import Nimble
import rNews
import UIKit
import Ra
import Result
import rNewsKit

class LocalNotificationHandlerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var dataRepository: FakeDatabaseUseCase! = nil

        var notificationSource: FakeNotificationSource! = nil

        var subject: LocalNotificationHandler! = nil

        beforeEach {
            injector = Injector()

            dataRepository = FakeDatabaseUseCase()
            injector.bind(DatabaseUseCase.self, toInstance: dataRepository)
            injector.bind(UrlOpener.self, toInstance: FakeUrlOpener())
            let articleUseCase = FakeArticleUseCase()
            articleUseCase.readArticleReturns("")
            articleUseCase.userActivityForArticleReturns(NSUserActivity(activityType: "com.example.test"))
            injector.bind(ArticleUseCase.self, toInstance: articleUseCase)

            subject = injector.create(LocalNotificationHandler)!

            notificationSource = FakeNotificationSource()
        }

        describe("enabling notifications") {
            beforeEach {
                subject.enableNotifications(notificationSource)
            }

            it("should enable local notifications for marking something as read") {
                expect(notificationSource.notificationSettings?.types).to(equal(UIUserNotificationType.Badge.union(.Alert).union(.Sound)))
                if let categories = notificationSource.notificationSettings?.categories {
                    expect(categories.count).to(equal(1))
                    if let category = categories.first {
                        expect(category.identifier).to(equal("default"))
                        expect(category.actionsForContext(.Minimal)?.count).to(equal(1))
                        if let action = category.actionsForContext(.Minimal)?.first {
                            expect(action.identifier).to(equal("read"))
                            expect(action.title).to(equal("Mark Read"))
                            expect(action.activationMode).to(equal(UIUserNotificationActivationMode.Background))
                        }

                        expect(category.actionsForContext(.Default)?.count).to(equal(1))
                        if let action = category.actionsForContext(.Default)?.first {
                            expect(action.identifier).to(equal("read"))
                            expect(action.title).to(equal("Mark Read"))
                            expect(action.activationMode).to(equal(UIUserNotificationActivationMode.Background))
                        }
                    }
                }
            }
        }
        
        describe("handling notifications") {
            var window: UIWindow! = nil
            var navController: UINavigationController! = nil

            let feed = Feed(title: "feedTitle", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feedIdentifier")
            let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [], enclosures: [])
            feed.addArticle(article)
            beforeEach {
                let note = UILocalNotification()
                note.category = "default"
                note.userInfo = ["feed": "feedIdentifier", "article": "articleIdentifier"]

                let splitVC = UISplitViewController()
                injector.bind(SettingsRepository.self, toInstance: SettingsRepository())
                navController = UINavigationController(rootViewController: injector.create(FeedsTableViewController)!)
                splitVC.viewControllers = [navController]


                window = UIWindow()
                window.rootViewController = splitVC

                subject.handleLocalNotification(note, window: window)
            }

            afterEach {
                window.hidden = true
                window = nil
            }

            it("makes a request for the feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds request succeeds with a feed for that article") {
                beforeEach {
                    dataRepository.feedsPromises.last?.resolve(.Success([feed]))
                }
                it("opens the app and show the article") {
                    expect(navController.viewControllers.count) == 3
                    if let articleController = (navController.topViewController as? UINavigationController)?.topViewController as? ArticleViewController {
                        expect(articleController.article) == article
                    }
                }
            }

            context("when the feeds request succeeds without a feed for that article") {
                beforeEach {
                    dataRepository.feedsPromises.last?.resolve(.Success([]))
                }

                it("just shows the list of feeds") {
                    expect(navController.viewControllers.count) == 1
                }
            }

            context("when the feeds request fails") {
                beforeEach {
                    dataRepository.feedsPromises.last?.resolve(.Failure(.Unknown))
                }

                it("just shows the list of feeds") {
                    expect(navController.viewControllers.count) == 1
                }
            }
        }

        describe("handling actions") {
            let feed = Feed(title: "feedTitle", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feedIdentifier")
            let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [], enclosures: [])
            feed.addArticle(article)

            describe("read") {
                beforeEach {
                    article.read = false
                    let note = UILocalNotification()
                    note.category = "default"
                    note.userInfo = ["feed": "feedIdentifier", "article": "articleIdentifier"]
                    subject.handleAction("read", notification: note)
                }

                it("makes a request for the feeds") {
                    expect(dataRepository.feedsPromises.count) == 1
                }

                context("when the feeds request succeeds with a feed for that article") {
                    beforeEach {
                        dataRepository.feedsPromises.last?.resolve(.Success([feed]))
                    }

                    it("should set the article's read value to true") {
                        expect(article.read) == true
                        expect(dataRepository.lastArticleMarkedRead) == article
                    }
                }

                context("when the feeds request succeeds without a feed for that article") {
                    beforeEach {
                        dataRepository.feedsPromises.last?.resolve(.Success([]))
                    }

                    it("does nothing") { // TODO: FOR NOW! (Should display a notification about the action erroring!)
                        expect(article.read) == false
                        expect(dataRepository.lastArticleMarkedRead).to(beNil())
                    }
                }

                context("when the feeds request fails") {
                    beforeEach {
                        dataRepository.feedsPromises.last?.resolve(.Failure(.Unknown))
                    }

                    it("does nothing") { // TODO: FOR NOW! (Should display a notification about the action erroring!)
                        expect(article.read) == false
                        expect(dataRepository.lastArticleMarkedRead).to(beNil())
                    }
                }
            }
        }
        
        describe("sending notifications") {
            let feed = Feed(title: "feedTitle", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feedIdentifier")
            let article = Article(title: "", link: nil, summary: "", authors: [], published: NSDate(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [], enclosures: [])
            feed.addArticle(article)

            beforeEach {
                subject.sendLocalNotification(notificationSource, article: article)
            }

            it("adds a local notification for that article") {
                expect(notificationSource.scheduledNotes.count).to(equal(1))
                if let note = notificationSource.scheduledNotes.first {
                    expect(note.category).to(equal("default"))
                    let feedTitle = article.feed?.displayTitle ?? ""
                    expect(note.alertBody).to(equal("New article in \(feedTitle): \(article.title)"))
                    expect(note.userInfo?.count).to(equal(2))
                    expect(note.userInfo?["feed"] as? String).to(equal(feed.identifier))
                    expect(note.userInfo?["article"] as? String).to(equal(article.identifier))
                }
            }
        }
    }
}

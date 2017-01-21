import Quick
import Nimble
import Tethys
import UIKit
import Ra
import Result
import TethysKit

class LocalNotificationHandlerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var dataRepository: FakeDatabaseUseCase! = nil

        var notificationSource: FakeNotificationSource! = nil

        var subject: LocalNotificationHandler! = nil

        beforeEach {
            injector = Injector()

            dataRepository = FakeDatabaseUseCase()
            injector.bind(kind: DatabaseUseCase.self, toInstance: dataRepository)
            let articleUseCase = FakeArticleUseCase()
            articleUseCase.readArticleReturns("")
            articleUseCase.userActivityForArticleReturns(NSUserActivity(activityType: "com.example.test"))
            injector.bind(kind: ArticleUseCase.self, toInstance: articleUseCase)

            subject = injector.create(kind: LocalNotificationHandler.self)!

            notificationSource = FakeNotificationSource()
        }

        describe("enabling notifications") {
            beforeEach {
                subject.enableNotifications(notificationSource)
            }

            it("should enable local notifications for marking something as read") {
                expect(notificationSource.notificationSettings?.types).to(equal(UIUserNotificationType.badge.union(.alert).union(.sound)))
                if let categories = notificationSource.notificationSettings?.categories {
                    expect(categories.count).to(equal(1))
                    if let category = categories.first {
                        expect(category.identifier).to(equal("default"))
                        expect(category.actions(for: .minimal)?.count).to(equal(1))
                        if let action = category.actions(for: .minimal)?.first {
                            expect(action.identifier).to(equal("read"))
                            expect(action.title).to(equal("Mark Read"))
                            expect(action.activationMode).to(equal(UIUserNotificationActivationMode.background))
                        }

                        expect(category.actions(for: .default)?.count).to(equal(1))
                        if let action = category.actions(for: .default)?.first {
                            expect(action.identifier).to(equal("read"))
                            expect(action.title).to(equal("Mark Read"))
                            expect(action.activationMode).to(equal(UIUserNotificationActivationMode.background))
                        }
                    }
                }
            }
        }
        
        describe("handling notifications") {
            var window: UIWindow! = nil
            var navController: UINavigationController! = nil

            let feed = Feed(title: "feedTitle", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feedIdentifier")
            let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: feed, flags: [])
            feed.addArticle(article)
            beforeEach {
                let note = UILocalNotification()
                note.category = "default"
                note.userInfo = ["feed": "feedIdentifier", "article": "articleIdentifier"]

                let splitVC = UISplitViewController()
                injector.bind(kind: SettingsRepository.self, toInstance: SettingsRepository())
                injector.bind(string: kMainQueue, toInstance: FakeOperationQueue())
                navController = UINavigationController(rootViewController: injector.create(kind: FeedsTableViewController.self)!)
                splitVC.viewControllers = [navController]


                window = UIWindow()
                window.rootViewController = splitVC

                subject.handleLocalNotification(note, window: window)
            }

            afterEach {
                window.isHidden = true
                window = nil
            }

            it("makes a request for the feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds request succeeds with a feed for that article") {
                beforeEach {
                    dataRepository.feedsPromises.last?.resolve(.success([feed]))
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
                    dataRepository.feedsPromises.last?.resolve(.success([]))
                }

                it("just shows the list of feeds") {
                    expect(navController.viewControllers.count) == 1
                }
            }

            context("when the feeds request fails") {
                beforeEach {
                    dataRepository.feedsPromises.last?.resolve(.failure(.unknown))
                }

                it("just shows the list of feeds") {
                    expect(navController.viewControllers.count) == 1
                }
            }
        }

        describe("handling actions") {
            let feed = Feed(title: "feedTitle", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feedIdentifier")
            let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: feed, flags: [])
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
                        dataRepository.feedsPromises.last?.resolve(.success([feed]))
                    }

                    it("should set the article's read value to true") {
                        expect(article.read) == true
                        expect(dataRepository.lastArticleMarkedRead) == article
                    }
                }

                context("when the feeds request succeeds without a feed for that article") {
                    beforeEach {
                        dataRepository.feedsPromises.last?.resolve(.success([]))
                    }

                    it("does nothing") { // TODO: FOR NOW! (Should display a notification about the action erroring!)
                        expect(article.read) == false
                        expect(dataRepository.lastArticleMarkedRead).to(beNil())
                    }
                }

                context("when the feeds request fails") {
                    beforeEach {
                        dataRepository.feedsPromises.last?.resolve(.failure(.unknown))
                    }

                    it("does nothing") { // TODO: FOR NOW! (Should display a notification about the action erroring!)
                        expect(article.read) == false
                        expect(dataRepository.lastArticleMarkedRead).to(beNil())
                    }
                }
            }
        }
        
        describe("sending notifications") {
            let feed = Feed(title: "feedTitle", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feedIdentifier")
            let article = Article(title: "", link: URL(string: "https://exapmle.com/1")!, summary: "", authors: [], published: Date(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, synced: false, estimatedReadingTime: 0, feed: feed, flags: [])
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

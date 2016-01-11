import Quick
import Nimble
import rNews
import UIKit
import Ra
import rNewsKit

class NotificationHandlerSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var dataReadWriter: FakeDataReadWriter! = nil

        var notificationSource: FakeNotificationSource! = nil

        var subject: NotificationHandler! = nil

        beforeEach {
            injector = Injector()

            dataReadWriter = FakeDataReadWriter()
            injector.bind(DataRetriever.self, toInstance: dataReadWriter)
            injector.bind(DataWriter.self, toInstance: dataReadWriter)

            subject = injector.create(NotificationHandler)!

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
            var article: Article! = nil
            beforeEach {
                let note = UILocalNotification()
                note.category = "default"
                note.userInfo = ["feed": "feedIdentifier", "article": "articleIdentifier"]

                let splitVC = UISplitViewController()
                navController = UINavigationController(rootViewController: injector.create(FeedsTableViewController)!)
                splitVC.viewControllers = [navController]

                let feed = Feed(title: "feedTitle", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feedIdentifier")
                article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [], enclosures: [])
                feed.addArticle(article)

                dataReadWriter.feedsList = [feed]

                window = UIWindow()
                window.rootViewController = splitVC

                subject.handleLocalNotification(note, window: window)
            }

            afterEach {
                window.hidden = true
                window = nil
            }

            it("should open the app and show the article") {
                expect(navController.viewControllers.count).to(equal(3))
                if let articleController = (navController.topViewController as? UINavigationController)?.topViewController as? ArticleViewController {
                    expect(articleController.article).to(equal(article))
                }
            }
        }
        
        describe("handling actions") {
            var article: Article! = nil
            beforeEach {
                let feed = Feed(title: "feedTitle", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feedIdentifier")
                article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [], enclosures: [])
                feed.addArticle(article)

                dataReadWriter.feedsList = [feed]
            }

            describe("read") {
                beforeEach {
                    let note = UILocalNotification()
                    note.category = "default"
                    note.userInfo = ["feed": "feedIdentifier", "article": "articleIdentifier"]
                    subject.handleAction("read", notification: note)
                }

                it("should set the article's read value to true") {
                    expect(article.read).to(beTruthy())
                    expect(dataReadWriter.lastArticleMarkedRead).to(equal(article))
                }
            }
        }
        
        describe("sending notifications") {
            var article: Article! = nil
            beforeEach {
                let feed = Feed(title: "feedTitle", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, identifier: "feedIdentifier")
                article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [], enclosures: [])
                feed.addArticle(article)

                dataReadWriter.feedsList = [feed]

                subject.sendLocalNotification(notificationSource, article: article)
            }

            it("should add a local notification for that article") {
                expect(notificationSource.scheduledNotes.count).to(equal(1))
                if let note = notificationSource.scheduledNotes.first {
                    expect(note.category).to(equal("default"))
                    let feedTitle = article.feed?.displayTitle ?? ""
                    expect(note.alertBody).to(equal("New article in \(feedTitle): \(article.title)"))
                    expect(note.userInfo?.count).to(equal(2))
                    expect(note.userInfo?["feed"] as? String).to(equal(article.feed?.identifier))
                    expect(note.userInfo?["article"] as? String).to(equal(article.identifier))
                }
            }
        }
    }
}

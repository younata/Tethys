import Quick
import Nimble
import rNews
import UIKit
import Ra

private class ApplicationMock: UIApplication {
    private var notificationSettings: UIUserNotificationSettings? = nil
    private override func registerUserNotificationSettings(notificationSettings: UIUserNotificationSettings) {
        self.notificationSettings = notificationSettings
    }

    private var scheduledNotes: [UILocalNotification] = []
    private override func presentLocalNotificationNow(notification: UILocalNotification) {
        scheduledNotes.append(notification)
    }

    override init() {
    }
}

class NotificationHandlerSpec: QuickSpec {
    override func spec() {
        
        var injector: Injector! = nil
        var app: ApplicationMock! = nil
        var dataManager: DataManagerMock! = nil

        var subject: NotificationHandler! = nil
//
//        var article: CoreDataArticle? = nil
//        var feed: CoreDataFeed? = nil

        beforeEach {
            injector = Injector()
            dataManager = DataManagerMock()
            injector.bind(DataManager.self, to: dataManager)

            app = ApplicationMock()

            subject = injector.create(NotificationHandler.self) as! NotificationHandler

//            feed = FeedObject(tuple: ("example feed", "http://example.com/feed", "", nil, [], 0, 0, nil), objectID: feedID)
//            article = ArticleObject(tuple: ("example article", "http://example.com/article", "", "", NSDate(), nil, "", false, [], feed, []), objectID: articleID)
        }

        describe("enabling notifications") {
            beforeEach {
                subject.enableNotifications(app)
            }

            it("should enable local notifications for marking something as read") {
                expect(app.notificationSettings?.types).to(equal(UIUserNotificationType.Badge.union(.Alert).union(.Sound)))
                if let categories = app.notificationSettings?.categories {
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
                navController = UINavigationController(rootViewController: FeedsTableViewController())
                splitVC.viewControllers = [navController]

                let feed = Feed(title: "feedTitle", url: nil, summary: "", query: "", tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil, identifier: "feedIdentifier")
                article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, feed: feed, flags: [], enclosures: [])

                window = UIWindow()
                window.rootViewController = splitVC

                subject.handleLocalNotification(note, window: window)
            }

            it("should open the app and show the article") {
                expect(navController.viewControllers.count).to(equal(2))
                if let articleController = navController.viewControllers.last as? ArticleViewController {
                    expect(articleController.article).to(equal(article))
                }
            }
        }
        
        describe("handling actions") {
            var article: Article! = nil
            beforeEach {
                let feed = Feed(title: "feedTitle", url: nil, summary: "", query: "", tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil, identifier: "feedIdentifier")
                article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, feed: feed, flags: [], enclosures: [])
            }
            describe("read") {
                beforeEach {
                    let note = UILocalNotification()
                    note.category = "default"
                    note.userInfo = ["feed": "feedIdentifier", "article": "articleIdentifier"]
                    subject.handleAction("", notification: note)
                }
                it("should set the article's read value to true") {
                    expect(article.read).to(beTruthy())
                    expect(dataManager.lastArticleMarkedRead).to(equal(article))
                }
            }
        }
        
        describe("sending notifications") {
            var article: Article! = nil
            beforeEach {
                let feed = Feed(title: "feedTitle", url: nil, summary: "", query: "", tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil, identifier: "feedIdentifier")
                article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "articleIdentifier", content: "", read: false, feed: feed, flags: [], enclosures: [])
                subject.sendLocalNotification(app, article: article)
            }

            it("should add a local notification for that article") {
                expect(app.scheduledNotes.count).to(equal(1))
                if let note = app.scheduledNotes.first {
                    expect(note.category).to(equal("default"))
                    let feedTitle = article.feed?.title ?? ""
                    expect(note.alertBody).to(equal("New article in \(feedTitle): \(article.title)"))
                    expect(note.userInfo?.count).to(equal(2))
                    expect(note.userInfo?["feed"] as? String).to(equal(article.feed?.identifier))
                    expect(note.userInfo?["article"] as? String).to(equal(article.identifier))
                }
            }
        }
    }
}

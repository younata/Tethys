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
            beforeEach {
                
            }

            it("should open the app and show the article") {

            }
        }
        
        describe("handling actions") {
            describe("read") {
                it("should set the article's read value to true") {

                }
            }
        }
        
        describe("sending notifications") {
        }
    }
}

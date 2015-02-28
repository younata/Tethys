import Quick
import Nimble

class NotificationHandlerSpec: QuickSpec {
    override func spec() {
        
        let app = UIApplication.sharedApplication()
        
        let window = UIWindow()
        
        var subject : NotificationHandler! = nil

        var ctx : NSManagedObjectContext! = nil

        var article: Article? = nil
        var feed: Feed? = nil

        beforeEach {
            subject = NotificationHandler()


//            feed = FeedObject(tuple: ("example feed", "http://example.com/feed", "", nil, [], 0, 0, nil), objectID: feedID)
//            article = ArticleObject(tuple: ("example article", "http://example.com/article", "", "", NSDate(), nil, "", false, [], feed, []), objectID: articleID)
        }
        
        sharedExamples("Opening articles") {(sharedExampleContext: SharedExampleContext) in
            
        }
        
        describe("handling notifications") {
            beforeEach {
                
            }
        }
        
        describe("handling actions") {
            describe("read") {
                it("should set the article's read value to true") {

                }
            }

            describe("view") {
                it("should open the app and show the article") {

                }
            }
        }
        
        describe("sending notifications") {
//            it("should send a notification") {
//                expect(article).toNot(beNil())
//                if let article = article {
//                    subject.sendLocalNotification(app, article: article)
//                    let scheduledNotes = app.scheduledLocalNotifications as [UILocalNotification]
//                    expect(scheduledNotes).toNot(beEmpty())
//                    var found = false
//
//                    let feedIDStr : String? = feedID.URIRepresentation().absoluteString
//                    let articleIDStr : String? = articleID.URIRepresentation().absoluteString
//
//                    for note in scheduledNotes {
//                        if note.category == "default" {
//                            if let userInfo = note.userInfo as? [String: String] {
//                                let feedInfoID = userInfo["feed"]
//                                let articleInfoID = userInfo["article"]
//                                if feedInfoID == feedIDStr && articleInfoID == articleIDStr {
//                                    found = true
//                                    break
//                                }
//                            }
//                        }
//                    }
//                    expect(found).to(beTruthy())
//                }
//            }
        }
    }
}

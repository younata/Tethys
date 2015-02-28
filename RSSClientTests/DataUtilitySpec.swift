import Quick
import Nimble
import Foundation

class DataUtilitySpec: QuickSpec {
    override func spec() {
        describe("updateFeed") {
            let item : MWFeedItem = MWFeedItem()
            let items : [MWFeedItem] = [item]
            beforeEach {
                item.title = "example"
                item.link = "http://example.com/"
                item.date = NSDate(timeIntervalSinceReferenceDate: 0)
                item.updated = NSDate(timeIntervalSinceReferenceDate: 10)
                item.summary = "summary"
                item.content = "content"
                item.author = "author"
                item.enclosures = [["url": "http://example.com/enclosure", "length": 64, "type": "text/text"]]
            }
//            DataUtility.updateFeed(<#feed: Feed#>, info: <#MWFeedInfo#>, items: <#[MWFeedItem]#>, context: <#NSManagedObjectContext#>, dataManager: <#DataManager#>)
        }

        describe("updateFeedImage") {
            let manager = ManagerMock(configuration: NSURLSessionConfiguration())
            context("when the feed doesn't have an existing image") {
                it("should download the image pointed at by info.imageURL and set it as the feed image") {
//                    manager.responseObj = 
//                    DataUtility.updateFeedImage(<#feed: Feed#>, info: <#MWFeedInfo#>, manager: manager)

//                    expect(manager.callsToRequest).to(equal(1))
//                    expect(feed.feedImage()).toNot(beNil())
                }
            }
            context("when the feed has an existing image") {
                it("should not update the feed image") {
//                    DataUtility.updateFeedImage(<#feed: Feed#>, info: <#MWFeedInfo#>, manager: manager)

//                    expect(manager.callsToRequest).to(equal(0))
//                    expect(feed.hasChanges).to(beFalsy())
                }
            }
        }
    }
}

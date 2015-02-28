import Quick
import Nimble
import Foundation

class DataUtilitySpec: QuickSpec {
    override func spec() {
        let ctx = managedObjectContext()
        var feed : Feed! = nil

        let info = MWFeedInfo()

        beforeEach {
            feed = createFeed(ctx)
        }

        describe("updateFeed") {
            let item = MWFeedItem()
            let items : [MWFeedItem] = [item]

            beforeEach {
                info.title = "example feed"
                info.link = "http://example.com"
                info.summary = "example"
                info.url = NSURL(string: "http://example.com")
info.imageURL = nil

                item.title = "example"
                item.link = "http://example.com/"
                item.date = NSDate(timeIntervalSinceReferenceDate: 0)
                item.updated = NSDate(timeIntervalSinceReferenceDate: 10)
                item.summary = "summary"
                item.content = "content"
                item.author = "author"
                item.enclosures = [["url": "http://example.com/enclosure", "length": 64, "type": "text/text"]]
            }
//            DataUtility.updateFeed(feed, info: info, items: items, context: ctx, dataManager: <#DataManager#>)
        }

        describe("updateFeedImage") {
            beforeEach {
                info.title = "example"
                info.link = "http://example.com"
                info.summary = "example"
                info.url = NSURL(string: "http://example.com")
                info.imageURL = "https://raw.githubusercontent.com/younata/RSSClient/master/RSSClient/Images.xcassets/AppIcon.appiconset/Icon@2x.png"
            }

            context("when the feed doesn't have an existing image") {
                it("should download the image pointed at by info.imageURL and set it as the feed image") {
                    DataUtility.updateFeedImage(feed, info: info, manager: Manager.sharedInstance)

                    expect(feed.hasChanges).toEventually(beTruthy())
                    expect(feed.feedImage()).toEventuallyNot(beNil())
                }
            }
            context("when the feed has an existing image") {
                beforeEach {
                    feed.image = UIImage(named: "AppIcon60x60")
                    feed.managedObjectContext?.save(nil)
                }
                it("should not update the feed image") {
                    DataUtility.updateFeedImage(feed, info: info, manager: Manager.sharedInstance)

                    expect(feed.hasChanges).to(beFalsy())
                }
            }
        }
    }
}

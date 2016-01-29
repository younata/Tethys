import Quick
import Nimble
import RealmSwift
@testable import rNewsKit

class RealmServiceSpec: QuickSpec {
    override func spec() {
        var subject: RealmService!
        var realm: Realm!

        var mainQueue: FakeOperationQueue!
        var searchIndex: FakeSearchIndex!

        beforeEach {
            let realmConf = Realm.Configuration(inMemoryIdentifier: "ThisIsWayEasierThanCoreData")
            realm = try! Realm(configuration: realmConf)
            try! realm.write {
                realm.deleteAll()
            }

            mainQueue = FakeOperationQueue()
            searchIndex = FakeSearchIndex()

            subject = RealmService(realm: realm, mainQueue: mainQueue, searchIndex: searchIndex)
        }

        xdescribe("create operations") {
            it("new feed creates a new feed object") {
                let expectation = self.expectationWithDescription("Create Feed")

                subject.createFeed { feed in
                    feed.title = "Hello"
                    feed.url = NSURL(string: "https://example.com/feed")
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1, handler: nil)

                let feeds = realm.objects(RealmFeed)
                expect(feeds.count) == 1
                guard let feed = feeds.first else { return }
                expect(feed.title) == "Hello"
                expect(feed.url) == "https://example.com/feed"
            }
        }
    }
}

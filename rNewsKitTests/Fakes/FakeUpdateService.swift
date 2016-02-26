import Foundation
@testable import rNewsKit

class FakeUpdateService: UpdateServiceType {
    var updatedFeed: Feed? = nil
    var updatedFeedCallback: ((Feed, NSError?) -> Void)? = nil

    func updateFeed(feed: Feed, callback: (Feed, NSError?) -> Void) {
        self.updatedFeed = feed
        self.updatedFeedCallback = callback
    }
}
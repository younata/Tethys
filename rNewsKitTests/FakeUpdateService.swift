import Foundation
@testable import rNewsKit

class FakeUpdateService: UpdateServiceType {
    var updatedFeed: Feed? = nil
    var updatedFeedCallback: (Feed -> Void)? = nil

    func updateFeed(feed: Feed, callback: Feed -> Void) {
        self.updatedFeed = feed
        self.updatedFeedCallback = callback
    }
}
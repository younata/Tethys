import Foundation
@testable import rNewsKit

class FakeUpdateService: UpdateServiceType {
    var updatedFeeds: [Feed] = []
    var updateFeedCallbacks: [((Feed, NSError?) -> Void)] = []

    func updateFeed(feed: Feed, callback: (Feed, NSError?) -> Void) {
        self.updatedFeeds.append(feed)
        self.updateFeedCallbacks.append(callback)
    }
}
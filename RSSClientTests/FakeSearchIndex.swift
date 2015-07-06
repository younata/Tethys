import Foundation
import CoreSpotlight
import rNewsKit

class FakeSearchIndex: SearchIndex {
    var lastItemsAdded: [NSObject] = []
    var lastAddCompletionHandler: (NSError?) -> (Void) = {_ in }
    func addItemsToIndex(items: [NSObject], completionHandler: (NSError?) -> (Void)) {
        if #available(iOS 9.0, *) {
            assert(items is [CSSearchableItem])
        } else {
            fatalError("not available on iOS <9.0")
        }
        lastItemsAdded += items
        lastAddCompletionHandler = completionHandler
    }

    var lastItemsDeleted: [String] = []
    var lastDeleteCompletionHandler: (NSError?) -> (Void) = {_ in }

    func deleteIdentifierFromIndex(items: [String], completionHandler: (NSError?) -> (Void)) {
        lastItemsDeleted = items
        lastDeleteCompletionHandler = completionHandler
    }

    init() {}
}

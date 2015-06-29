import Foundation
import CoreSpotlight
import rNews

class FakeSearchIndex: SearchIndex {
    var lastItemsAdded: [NSObject] = []
    var lastAddCompletionHandler: (NSError?) -> (Void) = {_ in }
    @available(iOS 9.0, *)
    func addItemsToIndex(items: [CSSearchableItem], completionHandler: (NSError?) -> (Void)) {
        lastItemsAdded = items
        lastAddCompletionHandler = completionHandler
    }

    var lastItemsDeleted: [String] = []
    var lastDeleteCompletionHandler: (NSError?) -> (Void) = {_ in }
    @available(iOS 9.0, *)
    func deleteDomainIdentifiersFromIndex(items: [String], completionHandler: (NSError?) -> (Void)) {
        lastItemsDeleted = items
        lastDeleteCompletionHandler = completionHandler
    }

    init() {}
}

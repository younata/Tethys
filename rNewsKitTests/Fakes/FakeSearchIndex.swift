import Foundation
#if os(iOS)
    import CoreSpotlight
#endif
import rNewsKit

class FakeSearchIndex: SearchIndex {
    var lastItemsAdded: [NSObject] = []
    var lastAddCompletionHandler: (NSError?) -> (Void) = {_ in }
    func addItemsToIndex(_ items: [NSObject], completionHandler: @escaping (NSError?) -> (Void)) {
        #if os(iOS)
            assert(items is [CSSearchableItem])
        #endif
        lastItemsAdded += items
        lastAddCompletionHandler = completionHandler
    }

    var lastItemsDeleted: [String] = []
    var lastDeleteCompletionHandler: (NSError?) -> (Void) = {_ in }

    func deleteIdentifierFromIndex(_ items: [String], completionHandler: @escaping (NSError?) -> (Void)) {
        lastItemsDeleted = items
        lastDeleteCompletionHandler = completionHandler
    }

    init() {}
}

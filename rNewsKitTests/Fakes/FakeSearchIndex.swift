import Foundation
#if os(iOS)
    import CoreSpotlight
#endif
import rNewsKit

class FakeSearchIndex: SearchIndex {
    var lastItemsAdded: [NSObject] = []
    var lastAddCompletionHandler: (Error?) -> (Void) = {_ in }
    func addItemsToIndex(_ items: [NSObject], completionHandler: @escaping (Error?) -> (Void)) {
        #if os(iOS)
            assert(items is [CSSearchableItem])
        #endif
        lastItemsAdded += items
        lastAddCompletionHandler = completionHandler
    }

    var lastItemsDeleted: [String] = []
    var lastDeleteCompletionHandler: (Error?) -> (Void) = {_ in }

    func deleteIdentifierFromIndex(_ items: [String], completionHandler: @escaping (Error?) -> (Void)) {
        lastItemsDeleted = items
        lastDeleteCompletionHandler = completionHandler
    }

    init() {}
}

import Foundation
#if os(iOS)
    import CoreSpotlight
#endif

public protocol SearchIndex: class {
    func addItemsToIndex(_ items: [NSObject], completionHandler: @escaping (Error?) -> (Void))
    func deleteIdentifierFromIndex(_ items: [String], completionHandler: @escaping (Error?) -> (Void))
}

#if os(iOS)
    @available(iOSApplicationExtension 9.0, *)
    extension CSSearchableIndex: SearchIndex {
        public func addItemsToIndex(_ items: [NSObject], completionHandler: @escaping (Error?) -> (Void)) {
            self.indexSearchableItems(items as! [CSSearchableItem], completionHandler: completionHandler)
        }

        public func deleteIdentifierFromIndex(_ items: [String], completionHandler: @escaping (Error?) -> (Void)) {
            self.deleteSearchableItems(withIdentifiers: items, completionHandler: completionHandler)
        }
    }
#endif

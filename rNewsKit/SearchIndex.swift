import Foundation
#if os(iOS)
    import CoreSpotlight
#endif

public protocol SearchIndex: class {
    func addItemsToIndex(_ items: [NSObject], completionHandler: (NSError?) -> (Void))
    func deleteIdentifierFromIndex(_ items: [String], completionHandler: (NSError?) -> (Void))
}

#if os(iOS)
    @available(iOSApplicationExtension 9.0, *)
    extension CSSearchableIndex: SearchIndex {
        public func addItemsToIndex(_ items: [NSObject], completionHandler: (NSError?) -> (Void)) {
            self.indexSearchableItems(items as! [CSSearchableItem], completionHandler: completionHandler)
        }

        public func deleteIdentifierFromIndex(_ items: [String], completionHandler: (NSError?) -> (Void)) {
            self.deleteSearchableItems(withIdentifiers: items, completionHandler: completionHandler)
        }
    }
#endif

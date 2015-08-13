import Foundation
import CoreSpotlight

public protocol SearchIndex {
    func addItemsToIndex(items: [NSObject], completionHandler: (NSError?) -> (Void))
    func deleteIdentifierFromIndex(items: [String], completionHandler: (NSError?) -> (Void))
}

@available(iOSApplicationExtension 9.0, *)
extension CSSearchableIndex: SearchIndex {
    public func addItemsToIndex(items: [NSObject], completionHandler: (NSError?) -> (Void)) {
            self.indexSearchableItems(items as! [CSSearchableItem], completionHandler: completionHandler)
    }

    public func deleteIdentifierFromIndex(items: [String], completionHandler: (NSError?) -> (Void)) {
        self.deleteSearchableItemsWithIdentifiers(items, completionHandler: completionHandler)
    }
}

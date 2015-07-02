import Foundation
import CoreSpotlight

public protocol SearchIndex {
    func addItemsToIndex(items: [NSObject], completionHandler: (NSError?) -> (Void))
    func deleteIdentifierFromIndex(items: [String], completionHandler: (NSError?) -> (Void))
}

extension CSSearchableIndex: SearchIndex {
    public func addItemsToIndex(items: [NSObject], completionHandler: (NSError?) -> (Void)) {
        if #available(iOS 9.0, *) {
            self.indexSearchableItems(items as! [CSSearchableItem], completionHandler: completionHandler)
        }
    }

    public func deleteIdentifierFromIndex(items: [String], completionHandler: (NSError?) -> (Void)) {
        self.deleteSearchableItemsWithIdentifiers(items, completionHandler: completionHandler)
    }
}

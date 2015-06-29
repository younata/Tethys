import Foundation
import CoreSpotlight

public protocol SearchIndex {}

@available(iOS 9.0, *)
public extension SearchIndex {
    @available(iOS 9.0, *)
    func addItemsToIndex(items: [CSSearchableItem], completionHandler: (NSError?) -> (Void)) {}

    @available(iOS 9.0, *)
    func deleteDomainIdentifiersFromIndex(items: [String], completionHandler: (NSError?) -> (Void)) {}
}

@available(iOS 9.0, *)
extension CSSearchableIndex: SearchIndex {
    public func addItemsToIndex(items: [CSSearchableItem], completionHandler: (NSError?) -> (Void)) {
        self.indexSearchableItems(items, completionHandler: completionHandler)
    }

    public func deleteDomainIdentifiersFromIndex(items: [String], completionHandler: (NSError?) -> (Void)) {
        self.deleteDomainIdentifiersFromIndex(items, completionHandler: completionHandler)
    }
}

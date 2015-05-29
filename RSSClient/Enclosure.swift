import Foundation

public class Enclosure: Equatable {
    public var url: NSURL {
        willSet {
            if newValue != url {
                self.updated = true
            }
        }
    }
    public var kind: String {
        willSet {
            if newValue != kind {
                self.updated = true
            }
        }
    }
    public var data: NSData? {
        willSet {
            if newValue != data {
                self.updated = true
            }
        }
    }
    public var article: Article? {
        willSet {
            if newValue != article {
                self.updated = true
                if let oldValue = article where contains(oldValue.enclosures, self) {
                    oldValue.removeEnclosure(self)
                }
                if let nv = newValue where !contains(nv.enclosures, self) {
                    nv.addEnclosure(self)
                }
            }
        }
    }

    public private(set) var updated: Bool = false

    public var downloaded: Bool {
        return data == nil
    }

    public init(url: NSURL, kind: String, data: NSData?, article: Article?) {
        self.url = url
        self.kind = kind
        self.data = data
        self.article = article
    }

    public private(set) var enclosureID: NSManagedObjectID? = nil

    public init(enclosure: CoreDataEnclosure, article: Article?) {
        url = NSURL(string: enclosure.url ?? "") ?? NSURL()
        kind = enclosure.kind ?? ""
        data = enclosure.data
        self.article = article
        enclosureID = enclosure.objectID
    }
}

public func ==(a: Enclosure, b: Enclosure) -> Bool {
    if let aEID = a.enclosureID, let bEID = b.enclosureID {
        return aEID.URIRepresentation() == bEID.URIRepresentation()
    }
    return a.url == b.url && a.kind == b.kind && a.data == b.data
}
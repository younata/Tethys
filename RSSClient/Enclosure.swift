import Foundation

class Enclosure: Equatable {
    var url : NSURL {
        willSet {
            if newValue != url {
                self.updated = true
            }
        }
    }
    var kind : String {
        willSet {
            if newValue != kind {
                self.updated = true
            }
        }
    }
    var data : NSData? {
        willSet {
            if newValue != data {
                self.updated = true
            }
        }
    }
    var article : Article? {
        willSet {
            if newValue != article {
                self.updated = true
            }
        }
        didSet {
            if let art = article where !contains(art.enclosures, self) {
                article?.addEnclosure(self)
            }
        }
    }

    internal private(set) var updated : Bool = false

    var downloaded : Bool {
        return data == nil
    }

    init(url: NSURL, kind: String, data: NSData?, article: Article?) {
        self.url = url
        self.kind = kind
        self.data = data
        self.article = article
    }

    private(set) var enclosureID : NSManagedObjectID? = nil

    init(enclosure: CoreDataEnclosure, article: Article?) {
        url = NSURL(string: enclosure.url ?? "") ?? NSURL()
        kind = enclosure.kind ?? ""
        data = enclosure.data
        self.article = article
        enclosureID = enclosure.objectID
    }
}

func ==(a: Enclosure, b: Enclosure) -> Bool {
    if let aEID = a.enclosureID, let bEID = b.enclosureID {
        return aEID.URIRepresentation() == bEID.URIRepresentation()
    }
    return a.url == b.url && a.kind == b.kind && a.data == b.data
}
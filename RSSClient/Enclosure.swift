import Foundation

struct Enclosure: Equatable {
    var url : NSURL
    var kind : String
    var data : NSData?
    var article : Article?

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
        url = NSURL(string: enclosure.url)!
        kind = enclosure.kind
        data = enclosure.data
        self.article = article
    }
}

func ==(a: Enclosure, b: Enclosure) -> Bool {
    if let aEID = a.enclosureID, let bEID = b.enclosureID {
        return aEID == bEID
    }
    return false
}
import RealmSwift
import Foundation
#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

class RealmString: Object {
    dynamic var string = ""
}

class RealmFeed: Object {
    dynamic var title: String?
    dynamic var url = "https://example.com/feed"
    dynamic var summary: String?
    dynamic var query: String?
    let tags = List<RealmString>()
    dynamic var waitPeriod: Int = 0
    dynamic var remainingWait: Int = 0
    let articles = List<RealmArticle>()
    dynamic var imageData: NSData?

    override static func primaryKey() -> String? {
        return "url"
    }
}

class RealmArticle: Object {
    dynamic var title: String?
    dynamic var link = "https://example.com/article"
    dynamic var summary: String?
    dynamic var author: String?
    dynamic var published = NSDate(timeIntervalSinceNow: 0)
    dynamic var updatedAt: NSDate?
    dynamic var identifier: String?
    dynamic var content: String?
    dynamic var read = false
    var estimatedReadingTime = RealmOptional<Int>()
    let flags = List<RealmString>()
    dynamic var feed: RealmFeed?
    let enclosures = List<RealmEnclosure>()

    override static func primaryKey() -> String? {
        return "link"
    }
}

class RealmEnclosure: Object {
    dynamic var url = "https://example.com/enclosure"
    dynamic var kind: String?
    dynamic var data: NSData?
    dynamic var article: RealmArticle?

    override static func primaryKey() -> String? {
        return "url"
    }
}

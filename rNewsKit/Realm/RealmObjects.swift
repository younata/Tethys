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
    dynamic var url = ""
    dynamic var summary: String?
    let tags = List<RealmString>()
    dynamic var waitPeriod: Int = 0
    dynamic var remainingWait: Int = 0
    dynamic var lastUpdated = Date(timeIntervalSinceReferenceDate: 0)
    var articles = LinkingObjects(fromType: RealmArticle.self, property: "feed")
    dynamic var imageData: Data?

    dynamic var id: String = UUID().uuidString
    override static func primaryKey() -> String? {
        return "id"
    }

    override static func indexedProperties() -> [String] {
        return ["url", "title"]
    }
}

class RealmAuthor: Object {
    dynamic var name = ""
    dynamic var email: String?

    dynamic var id: String = UUID().uuidString
    override static func primaryKey() -> String? {
        return "id"
    }

    override static func indexedProperties() -> [String] {
        return ["name", "email"]
    }
}

class RealmArticle: Object {
    dynamic var title: String?
    dynamic var link = ""
    dynamic var summary: String?
    dynamic var published = Date(timeIntervalSinceNow: 0)
    dynamic var updatedAt: Date?
    dynamic var identifier: String?
    dynamic var content: String?
    dynamic var read = false
    dynamic var estimatedReadingTime = 0
    let flags = List<RealmString>()
    dynamic var feed: RealmFeed?
    let authors = List<RealmAuthor>()
    let relatedArticles = List<RealmArticle>()

    dynamic var id: String = UUID().uuidString
    override static func primaryKey() -> String? {
        return "id"
    }

    override static func indexedProperties() -> [String] {
        return ["link", "published", "updatedAt", "title", "read"]
    }
}

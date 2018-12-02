import RealmSwift
import Foundation
#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

final class RealmString: Object {
    dynamic var string = ""

    override static func indexedProperties() -> [String] {
        return ["string"]
    }
}

final class RealmFeed: Object {
    dynamic var title: String?
    dynamic var url = ""
    dynamic var summary: String?
    let tags = List<RealmString>()
    var articles = LinkingObjects(fromType: RealmArticle.self, property: "feed")
    dynamic var imageData: Data?
    dynamic var settings: RealmSettings?

    dynamic var id: String = UUID().uuidString
    override static func primaryKey() -> String? {
        return "id"
    }

    override static func indexedProperties() -> [String] {
        return ["url", "title"]
    }
}

final class RealmAuthor: Object {
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

final class RealmArticle: Object {
    dynamic var title: String?
    dynamic var link = ""
    dynamic var summary: String?
    dynamic var published = Date(timeIntervalSinceNow: 0)
    dynamic var updatedAt: Date?

    dynamic var date: Date { return updatedAt ?? published }

    dynamic var identifier: String?
    dynamic var content: String?
    dynamic var read = false
    dynamic var estimatedReadingTime: Double = 0
    dynamic var synced = false
    let flags = List<RealmString>()
    dynamic var feed: RealmFeed?
    let authors = List<RealmAuthor>()

    dynamic var id: String = UUID().uuidString
    override static func primaryKey() -> String? {
        return "id"
    }

    override static func indexedProperties() -> [String] {
        return ["link", "published", "updatedAt", "title", "read"]
    }
}

final class RealmSettings: Object {
    dynamic var maxNumberOfArticles = 0
}

import RealmSwift
import Foundation
#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

final class RealmString: Object {
    @objc dynamic var string: String = ""

    convenience init(string: String) {
        self.init(value: ["string": string])
    }

    override static func primaryKey() -> String? {
        return "string"
    }
}

final class RealmFeed: Object {
    @objc dynamic var title = ""
    @objc dynamic var url = ""
    @objc dynamic var summary = ""
    let tags = List<RealmString>()
    var articles = LinkingObjects(fromType: RealmArticle.self, property: "feed")
    @objc dynamic var imageData: Data?
    @objc dynamic var settings: RealmSettings?

    @objc dynamic var id: String = UUID().uuidString
    override static func primaryKey() -> String? {
        return "id"
    }

    override static func indexedProperties() -> [String] {
        return ["url", "title"]
    }
}

final class RealmAuthor: Object {
    @objc dynamic var name = ""
    @objc dynamic var email: String?

    @objc dynamic var id: String = UUID().uuidString
    override static func primaryKey() -> String? {
        return "id"
    }

    override static func indexedProperties() -> [String] {
        return ["name", "email"]
    }
}

final class RealmArticle: Object {
    @objc dynamic var title: String?
    @objc dynamic var link = ""
    @objc dynamic var summary: String?
    @objc dynamic var published = Date(timeIntervalSinceNow: 0)
    @objc dynamic var updatedAt: Date?

    @objc dynamic var date: Date { return updatedAt ?? published }

    @objc dynamic var identifier: String?
    @objc dynamic var content: String?
    @objc dynamic var read = false
    @objc dynamic var estimatedReadingTime: Double = 0
    @objc dynamic var feed: RealmFeed?
    let authors = List<RealmAuthor>()

    @objc dynamic var id: String = UUID().uuidString
    override static func primaryKey() -> String? {
        return "id"
    }

    override static func indexedProperties() -> [String] {
        return ["link", "published", "updatedAt", "title", "read"]
    }
}

final class RealmSettings: Object {
    @objc dynamic var maxNumberOfArticles = 0
}

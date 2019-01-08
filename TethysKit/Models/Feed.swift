import Foundation
import RealmSwift

#if os(iOS)
    import UIKit
    public typealias Image=UIImage
#else
    import Cocoa
    public typealias Image=NSImage
#endif

public final class Feed: Hashable, CustomStringConvertible {
    public internal(set) var title: String

    public var displayTitle: String {
        if self.title.isEmpty {
            return self.url.absoluteString
        }
        return self.title
    }

    public internal(set) var url: URL
    public internal(set) var summary: String

    public var displaySummary: String { return self.summary }

    public internal(set) var tags: [String]

    public internal(set) var settings: Settings?
    public internal(set) var image: Image?

    public internal(set) var identifier: String

    public internal(set) var unreadCount: Int

    public func hash(into hasher: inout Hasher) {
        if let id = self.feedID as? String {
            hasher.combine(id)
            return
        }

        hasher.combine(self.title)
        hasher.combine(self.url)
        hasher.combine(self.summary)
        hasher.combine(self.tags)

        if let image = self.image {
            hasher.combine(image)
        }
    }

    public var description: String {
        return "Feed: title: \(title), url: \(url), summary: \(summary), tags: \(tags)\n"
    }

    public init(title: String, url: URL, summary: String, tags: [String], unreadCount: Int = 0, image: Image? = nil,
                identifier: String = "", settings: Settings? = nil) {
        self.title = title
        self.url = url
        self.summary = summary
        self.tags = tags
        self.image = image
        self.unreadCount = unreadCount
        self.identifier = identifier
        self.settings = settings
    }

    public private(set) var feedID: AnyObject?

    internal init(realmFeed feed: RealmFeed) {
        self.title = feed.title
        self.url = URL(string: feed.url)!
        self.summary = feed.summary
        self.tags = feed.tags.map { $0.string }

        if let data = feed.imageData {
            self.image = Image(data: data)
        } else {
            self.image = nil
        }
        self.feedID = feed.id as AnyObject
        self.identifier = feed.id
        self.unreadCount = feed.articles.filter(NSPredicate(format: "read == false")).count

        if let settings = feed.settings {
            self.settings = Settings(realmSettings: settings)
        } else {
            self.settings = nil

        }
    }
}

public func == (lhs: Feed, rhs: Feed) -> Bool {
    if let aID = lhs.feedID as? URL, let bID = rhs.feedID as? URL {
        return aID == bID
    }
    return lhs.title == rhs.title && lhs.url == rhs.url && lhs.summary == rhs.summary && lhs.tags == rhs.tags
}

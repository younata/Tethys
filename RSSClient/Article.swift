import Foundation
import CoreData
import JavaScriptCore

@objc public protocol ArticleJSExport: JSExport {
    var title: String { get set }
    var link: NSURL? { get set }
    var summary: String { get set }
    var author: String { get set }
    var published: NSDate { get set }
    var updatedAt: NSDate? { get set }
    var identifier: String { get set }
    var content: String { get set }
    var read: Bool { get set }
    weak var feed: Feed? { get set }
    var flags: [String] { get }
    var enclosures: [Enclosure] { get }
}

@objc public class Article: NSObject, ArticleJSExport {
    dynamic public var title: String {
        willSet {
            if newValue != title {
                self.updated = true
            }
        }
    }
    dynamic public var link: NSURL? {
        willSet {
            if newValue != link {
                self.updated = true
            }
        }
    }
    dynamic public var summary: String {
        willSet {
            if newValue != summary {
                self.updated = true
            }
        }
    }
    dynamic public var author: String {
        willSet {
            if newValue != author {
                self.updated = true
            }
        }
    }
    dynamic public var published: NSDate {
        willSet {
            if newValue != published {
                self.updated = true
            }
        }
    }
    dynamic public var updatedAt: NSDate? {
        willSet {
            if newValue != updatedAt {
                self.updated = true
            }
        }
    }
    dynamic public var identifier: String {
        willSet {
            if newValue != identifier {
                self.updated = true
            }
        }
    }
    dynamic public var content: String {
        willSet {
            if newValue != content {
                self.updated = true
            }
        }
    }
    dynamic public var read: Bool {
        willSet {
            if newValue != read {
                self.updated = true
            }
        }
    }
    weak dynamic public var feed: Feed? {
        willSet {
            if newValue != feed && newValue?.isQueryFeed != true {
                self.updated = true
                if let oldValue = feed where oldValue.articles.contains(self) {
                    oldValue.removeArticle(self)
                }
                if let nv = newValue where !nv.articles.contains(self) {
                    nv.addArticle(self)
                }
            }
        }
    }
    dynamic public private(set) var flags: [String] = []
    dynamic public private(set) var enclosures: [Enclosure] = []

    internal private(set) var updated: Bool = false

    public override var hashValue: Int {
        if let id = articleID {
            return id.URIRepresentation().hash
        }
        let nonNilHashValues = title.hashValue ^ summary.hashValue ^ author.hashValue ^
            published.hash ^ identifier.hashValue ^ content.hashValue & read.hashValue
        let flagsHashValues = flags.reduce(0) { $0 ^ $1.hashValue }
        let possiblyNilHashValues: Int
        if let link = link, updatedAt = updatedAt {
            possiblyNilHashValues = link.hash ^ updatedAt.hash
        } else {
            possiblyNilHashValues = 0
        }
        return nonNilHashValues ^ flagsHashValues ^ possiblyNilHashValues
    }

    public override func isEqual(object: AnyObject?) -> Bool {
        guard let b = object as? Article else {
            return false
        }
        if let aID = self.articleID, let bID = b.articleID {
            return aID.URIRepresentation() == bID.URIRepresentation()
        }
        return self.title == b.title && self.link == b.link && self.summary == b.summary &&
            self.author == b.author && self.published == b.published && self.updatedAt == b.updatedAt &&
            self.identifier == b.identifier && self.content == b.content && self.read == b.read &&
            self.flags == b.flags
    }

    public override var description: String {
        return "Article: title: \(title), link: \(link), summary: \(summary), author: \(author), published: \(published), updated: \(updatedAt), identifier: \(identifier), content: \(content), read: \(read)\n"
    }

    public init(title: String, link: NSURL?, summary: String, author: String, published: NSDate,
        updatedAt: NSDate?, identifier: String, content: String, read: Bool, feed: Feed?,
        flags: [String], enclosures: [Enclosure]) {
            self.title = title
            self.link = link
            self.summary = summary
            self.author = author
            self.published = published
            self.updatedAt = updatedAt
            self.identifier = identifier
            self.content = content
            self.read = read
            self.feed = feed
            self.flags = flags
            self.enclosures = enclosures
            updated = false
            super.init()
            for enclosure in enclosures {
                enclosure.article = self
            }
    }

    public private(set) var articleID: NSManagedObjectID? = nil

    internal init(article: CoreDataArticle, feed: Feed?) {
        title = article.title ?? ""
        if let articleLink = article.link {
            link = NSURL(string: articleLink)
        } else {
            link = nil
        }

        summary = article.summary ?? ""
        author = article.author ?? ""
        published = article.published ?? NSDate()
        updatedAt = article.updatedAt
        identifier = article.objectID.URIRepresentation().absoluteString ?? ""
        content = article.content ?? ""
        read = article.read
        self.feed = feed
        flags = article.flags
        let enclosuresList = Array(article.enclosures)
        super.init()
        enclosures = enclosuresList.map { Enclosure(enclosure: $0, article: self) }

        articleID = article.objectID

        updated = false
    }
    public func addFlag(flag: String) {
        if !self.flags.contains(flag) {
            self.flags.append(flag)
            updated = true
        }
    }

    public func removeFlag(flag: String) {
        if self.flags.contains(flag) {
            self.flags = self.flags.filter { $0 != flag }
            updated = true
        }
    }

    public func addEnclosure(enclosure: Enclosure) {
        if !self.enclosures.contains(enclosure) {
            self.enclosures.append(enclosure)
            if let otherArticle = enclosure.article {
                otherArticle.removeEnclosure(enclosure)
            }
            enclosure.article = self
            updated = true
        }
    }

    public func removeEnclosure(enclosure: Enclosure) {
        if self.enclosures.contains(enclosure) {
            self.enclosures = self.enclosures.filter { $0 != enclosure }
            if enclosure.article == self {
                enclosure.article = nil
            }
            updated = true
        }
    }
}
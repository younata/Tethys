import Foundation
import CoreData
import JavaScriptCore

public final class Article: NSObject {
    public internal(set) var title: String {
        willSet {
            if newValue != title {
                self.updated = true
            }
        }
    }
    public internal(set) var link: URL? {
        willSet {
            if newValue != link {
                self.updated = true
            }
        }
    }
    public internal(set) var summary: String {
        willSet {
            if newValue != summary {
                self.updated = true
            }
        }
    }
    public internal(set) var authors: [Author] {
        willSet {
            if newValue != authors {
                self.updated = true
            }
        }
    }
    public internal(set) var published: Date {
        willSet {
            if newValue != published {
                self.updated = true
            }
        }
    }
    public internal(set) var updatedAt: Date? {
        willSet {
            if newValue != updatedAt {
                self.updated = true
            }
        }
    }
    public internal(set) var identifier: String {
        willSet {
            if newValue != identifier {
                self.updated = true
            }
        }
    }
    public internal(set) var content: String {
        willSet {
            if newValue != content {
                self.updated = true
            }
        }
    }
    public internal(set) var estimatedReadingTime: Int {
        willSet {
            if newValue != estimatedReadingTime {
                self.updated = true
            }
        }
    }
    public var read: Bool {
        willSet {
            if newValue != read {
                self.updated = true
            }
        }
    }
    weak public internal(set) var feed: Feed? {
        didSet {
            if oldValue != feed {
                self.updated = true
                if let oldValue = oldValue, oldValue.articlesArray.contains(self) {
                    oldValue.removeArticle(self)
                }
                if let nv = feed, !nv.articlesArray.contains(self) {
                    nv.addArticle(self)
                }
            }
        }
    }
    public private(set) var flags: [String] = []

    public private(set) var relatedArticles = DataStoreBackedArray<Article>()
    public var relatedArticlesArray: [Article] { return Array(self.relatedArticles) }

    internal private(set) var updated: Bool = false

    public override var hashValue: Int {
        if let id = articleID as? NSManagedObjectID {
            return id.uriRepresentation().hash
        } else if let id = articleID as? String {
            return id.hash
        }
        let authorsHashValue = authors.reduce(0) { $0 ^ $1.hashValue }
        let nonNilHashValues = title.hashValue ^ summary.hashValue ^ authorsHashValue ^
            published.hash ^ identifier.hashValue ^ content.hashValue & read.hashValue &
            estimatedReadingTime.hashValue
        let flagsHashValues = flags.reduce(0) { $0 ^ $1.hashValue }
        var possiblyNilHashValues = 0
        if let link = link {
            possiblyNilHashValues ^= link.hashValue
        }
        if let updatedAt = updatedAt {
            possiblyNilHashValues ^= updatedAt.hash
        }
        return nonNilHashValues ^ flagsHashValues ^ possiblyNilHashValues
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let b = object as? Article else {
            return false
        }
        if let aID = self.articleID as? NSManagedObjectID, let bID = b.articleID as? NSManagedObjectID {
            return aID.uriRepresentation() == bID.uriRepresentation()
        } else if let aID = self.articleID as? String, let bID = b.articleID as? String {
            return aID == bID
        }
        return self.title == b.title && self.link == b.link && self.summary == b.summary &&
            self.authors == b.authors && self.published == b.published && self.updatedAt == b.updatedAt &&
            self.identifier == b.identifier && self.content == b.content && self.read == b.read &&
            self.flags == b.flags && self.estimatedReadingTime == b.estimatedReadingTime
    }

    public override var description: String {
        // swiftlint:disable line_length
        return "(Article: title: \(title), link: \(link), summary: \(summary), author: \(authors), published: \(published), updated: \(updatedAt), identifier: \(identifier), content: \(content), read: \(read), estimatedReadingTime: \(estimatedReadingTime))\n"
        // swiftlint:enable line_length
    }

    // swiftlint:disable function_parameter_count
    public init(title: String, link: URL?, summary: String, authors: [Author], published: Date,
        updatedAt: Date?, identifier: String, content: String, read: Bool, estimatedReadingTime: Int,
        feed: Feed?, flags: [String]) {
            self.title = title
            self.link = link
            self.summary = summary
            self.authors = authors
            self.published = published
            self.updatedAt = updatedAt
            self.identifier = identifier
            self.content = content
            self.read = read
            self.feed = feed
            self.flags = flags
            self.estimatedReadingTime = estimatedReadingTime
            super.init()
            self.updated = false
    }
    // swiftlint:enable function_parameter_count

    internal private(set) var articleID: AnyObject? = nil

    internal init(coreDataArticle article: CoreDataArticle, feed: Feed?) {
        title = article.title ?? ""
        if let articleLink = article.link {
            link = URL(string: articleLink)
        } else {
            link = nil
        }

        summary = article.summary ?? ""
        authors = [Author(article.author ?? "")]
        published = article.published ?? Date()
        updatedAt = article.updatedAt
        identifier = article.objectID.uriRepresentation().absoluteString ?? ""
        content = article.content ?? ""
        read = article.read
        if let readingTime = article.estimatedReadingTime?.intValue {
            estimatedReadingTime = readingTime
        } else {
            let readingTime = estimateReadingTime(article.content ?? article.summary ?? "")
            article.estimatedReadingTime = NSNumber(value: readingTime)
            estimatedReadingTime = readingTime
        }
        self.feed = feed
        self.flags = article.flags
        super.init()
        self.relatedArticles = DataStoreBackedArray(entityName: "Article",
            predicate: NSPredicate(format: "self in %@", article.relatedArticles),
            managedObjectContext: article.managedObjectContext!,
            conversionFunction: {
                let article = $0 as! CoreDataArticle
                let feed: Feed?
                if let coreDataFeed = article.feed {
                    feed = Feed(coreDataFeed: coreDataFeed)
                } else { feed = nil }
                return Article(coreDataArticle: article, feed: feed)
        })

        self.articleID = article.objectID

        self.updated = false
    }

    internal init(realmArticle article: RealmArticle, feed: Feed?) {
        title = article.title ?? ""
        link = URL(string: article.link)
        summary = article.summary ?? ""

        self.authors = article.authors.map(Author.init)
        published = article.published ?? Date()
        updatedAt = article.updatedAt
        identifier = article.id
        content = article.content ?? ""
        read = article.read
        estimatedReadingTime = article.estimatedReadingTime
        self.feed = feed
        self.flags = article.flags.map { $0.string }
        super.init()
        if let realm = article.realm {
            let relatedArticleIds = article.relatedArticles.map { $0.id }
            self.relatedArticles = DataStoreBackedArray(realmDataType: RealmArticle.self,
                predicate: NSPredicate(format: "id IN %@", relatedArticleIds),
                realmConfiguration: realm.configuration,
                conversionFunction: { object in
                    let article = object as! RealmArticle
                    let feed: Feed?
                    if let realmFeed = article.feed {
                        feed = Feed(realmFeed: realmFeed)
                    } else { feed = nil }
                    return Article(realmArticle: article, feed: feed)
            })
        }
        self.articleID = article.id
        self.updated = false
    }

    public func addFlag(_ flag: String) {
        if !self.flags.contains(flag) {
            self.flags.append(flag)
            self.updated = true
        }
    }

    public func removeFlag(_ flag: String) {
        if self.flags.contains(flag) {
            self.flags = self.flags.filter { $0 != flag }
            self.updated = true
        }
    }

    public func addRelatedArticle(_ article: Article) {
        guard article != self else { return }
        if !self.relatedArticles.contains(article) {
            self.relatedArticles.append(article)
            article.addRelatedArticle(self)
            self.updated = true
        }
    }

    public func removeRelatedArticle(_ article: Article) {
        if self.relatedArticles.contains(article) {
            self.relatedArticles.remove(article)
            article.removeRelatedArticle(self)
            self.updated = true
        }
    }
}

public func == (lhs: Article, rhs: Article) -> Bool {
    return lhs.isEqual(rhs)
}

import Foundation

public final class Article: NSObject {
    public internal(set) var title: String {
        willSet {
            if newValue != title {
                self.updated = true
            }
        }
    }
    public internal(set) var link: URL {
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
    @available(*, deprecated, message: "Use a service to get the article date")
    public internal(set) var published: Date {
        willSet {
            if newValue != published {
                self.updated = true
            }
        }
    }
    @available(*, deprecated, message: "Use a service to get the article date")
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
    public var read: Bool {
        willSet {
            if newValue != read {
                self.updated = true
            }
        }
    }

    @available(*, deprecated, message: "Query an ArticleService for the feed")
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

    internal private(set) var updated: Bool = false

    @available(*, deprecated, message: "Query an ArticleService for the author string")
    public var authorsString: String {
        return self.authors.map({$0.description}).joined(separator: ", ")
    }

    public override var hash: Int {
        if let id = articleID as? String {
            return id.hash
        }
        let authorsHashValue = authors.reduce(0) { $0 ^ $1.hashValue }
        return title.hashValue ^ summary.hashValue ^ authorsHashValue ^
            published.hashValue ^ identifier.hashValue ^ content.hashValue ^ read.hashValue ^
            link.hashValue
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let b = object as? Article else {
            return false
        }
        if let aID = self.articleID as? String, let bID = b.articleID as? String {
            return aID == bID
        }
        return self.title == b.title && self.link == b.link && self.summary == b.summary &&
            self.authors == b.authors && self.published == b.published && self.updatedAt == b.updatedAt &&
            self.identifier == b.identifier && self.content == b.content && self.read == b.read
    }

    public override var description: String {
        // swiftlint:disable line_length
        return "(Article: title: \(title), link: \(link), summary: \(summary), author: \(authors), published: \(published), updated: \(String(describing: updatedAt)), identifier: \(identifier), content: \(content), read: \(read))\n"
        // swiftlint:enable line_length
    }

    public init(title: String, link: URL, summary: String, authors: [Author], published: Date,
                updatedAt: Date?, identifier: String, content: String, read: Bool, feed: Feed?) {
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
        super.init()
        self.updated = false
    }

    internal private(set) var articleID: AnyObject?

    internal init(realmArticle article: RealmArticle, feed: Feed?) {
        title = article.title ?? ""
        link = URL(string: article.link)!
        summary = article.summary ?? ""

        self.authors = article.authors.map(Author.init)
        published = article.published
        updatedAt = article.updatedAt
        identifier = article.id
        content = article.content ?? ""
        read = article.read
        self.feed = feed
        super.init()
        self.articleID = article.id as AnyObject?
        self.updated = false
    }
}

public func == (lhs: Article, rhs: Article) -> Bool {
    return lhs.isEqual(rhs)
}

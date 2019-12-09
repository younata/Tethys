import Foundation

public struct Article: CustomStringConvertible, Hashable {
    public var title: String
    public var link: URL
    public var summary: String

    public var authors: [Author]
    public var identifier: String
    public var content: String
    public var read: Bool
    internal var published: Date
    internal var updated: Date?

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.authors)
        hasher.combine(self.title)
        hasher.combine(self.summary)
        hasher.combine(self.identifier)
        hasher.combine(self.content)
        hasher.combine(self.read)
        hasher.combine(self.link)
    }

    public var description: String {
        let dateFormatter = ISO8601DateFormatter()
        let publishedDateString = dateFormatter.string(from: self.published)
        let updatedDateString: String
        if let updated = self.updated {
            updatedDateString = dateFormatter.string(from: updated)
        } else {
            updatedDateString = "nil"
        }
        // swiftlint:disable line_length
        return "(Article: title: \(title), link: \(link), summary: \(summary), author: \(authors), identifier: \(identifier), content: \(content), read: \(read), published: \(publishedDateString), updated: \(updatedDateString)\n"
        // swiftlint:enable line_length
    }

    public init(title: String, link: URL, summary: String, authors: [Author], identifier: String, content: String,
                read: Bool, published: Date, updated: Date?) {
        self.title = title
        self.link = link
        self.summary = summary
        self.authors = authors
        self.identifier = identifier
        self.content = content
        self.read = read
        self.published = published
        self.updated = updated
    }

    internal private(set) var articleID: AnyObject?

    internal init(realmArticle article: RealmArticle) {
        title = article.title ?? ""
        link = URL(string: article.link)!
        summary = article.summary ?? ""

        self.authors = article.authors.map(Author.init)
        identifier = article.identifier ?? ""
        content = article.content ?? ""
        read = article.read
        self.articleID = article.id as AnyObject?
        published = article.published
        updated = article.updatedAt
    }
}

public func == (lhs: Article, rhs: Article) -> Bool {
    return lhs.title == rhs.title && lhs.link == rhs.link && lhs.summary == rhs.summary && lhs.authors == rhs.authors &&
        lhs.identifier == rhs.identifier && lhs.content == rhs.content && lhs.read == rhs.read &&
        lhs.published == rhs.published && lhs.updated == rhs.updated
}

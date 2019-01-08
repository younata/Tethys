import Foundation

public struct Article: CustomStringConvertible, Hashable {
    public var title: String
    public var link: URL
    public var summary: String

    public var authors: [Author]
    public var identifier: String
    public var content: String
    public var read: Bool

    public func hash(into hasher: inout Hasher) {
        if let id = self.articleID as? String {
            hasher.combine(id)
            return
        }
        hasher.combine(self.authors)
        hasher.combine(self.title)
        hasher.combine(self.summary)
        hasher.combine(self.identifier)
        hasher.combine(self.content)
        hasher.combine(self.read)
        hasher.combine(self.link)
    }

    public var description: String {
        // swiftlint:disable line_length
        return "(Article: title: \(title), link: \(link), summary: \(summary), author: \(authors), identifier: \(identifier), content: \(content), read: \(read))\n"
        // swiftlint:enable line_length
    }

    public init(title: String, link: URL, summary: String, authors: [Author], identifier: String, content: String,
                read: Bool) {
        self.title = title
        self.link = link
        self.summary = summary
        self.authors = authors
        self.identifier = identifier
        self.content = content
        self.read = read
    }

    internal private(set) var articleID: AnyObject?

    internal init(realmArticle article: RealmArticle) {
        title = article.title ?? ""
        link = URL(string: article.link)!
        summary = article.summary ?? ""

        self.authors = article.authors.map(Author.init)
        identifier = article.id
        content = article.content ?? ""
        read = article.read
        self.articleID = article.id as AnyObject?
    }
}

public func == (lhs: Article, rhs: Article) -> Bool {
    if let aID = lhs.articleID as? String, let bID = rhs.articleID as? String {
        return aID == bID
    }
    return lhs.title == rhs.title && lhs.link == rhs.link && lhs.summary == rhs.summary && lhs.authors == rhs.authors &&
        lhs.identifier == rhs.identifier && lhs.content == rhs.content && lhs.read == rhs.read
}

@testable import TethysKit

struct FakeImportableFeed: ImportableFeed {
    let title: String
    let url: URL
    let description: String
    let lastUpdated: Date
    let imageURL: URL?

    var articles: [FakeImportableArticle]

    var importableArticles: [ImportableArticle] {
        return self.articles.map { $0 as ImportableArticle }
    }

    init(title: String, link: URL, description: String, lastUpdated: Date, imageURL: URL?, articles: [FakeImportableArticle] = []) {
        self.title = title
        self.url = link
        self.description = description
        self.lastUpdated = lastUpdated
        self.imageURL = imageURL
        self.articles = articles
    }
}

struct FakeImportableArticle: ImportableArticle {
    let title: String
    let url: URL
    let summary: String
    let content: String
    let published: Date
    let updated: Date?
    let read: Bool

    var authors: [FakeImportableAuthor]

    var importableAuthors: [ImportableAuthor] {
        return self.authors.map { $0 as ImportableAuthor }
    }

    init(title: String, url: URL, summary: String, content: String, published: Date, updated: Date?, read: Bool, authors: [FakeImportableAuthor] = []) {
        self.title = title
        self.url = url
        self.summary = summary
        self.content = content
        self.published = published
        self.updated = updated
        self.read = read
        self.authors = authors
    }
}

struct FakeImportableAuthor: ImportableAuthor {
    let name: String
    let email: URL?

    init(name: String, email: URL?) {
        self.name = name
        self.email = email
    }
}

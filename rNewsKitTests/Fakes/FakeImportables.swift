@testable import rNewsKit

struct FakeImportableFeed: ImportableFeed {
    let title: String
    let link: NSURL
    let description: String
    let imageURL: NSURL?

    var articles: [FakeImportableArticle]

    var importableArticles: [ImportableArticle] {
        return self.articles.map { $0 as ImportableArticle }
    }

    init(title: String, link: NSURL, description: String, imageURL: NSURL?, articles: [FakeImportableArticle] = []) {
        self.title = title
        self.link = link
        self.description = description
        self.imageURL = imageURL
        self.articles = articles
    }
}

struct FakeImportableArticle: ImportableArticle {
    let title: String
    let url: NSURL
    let summary: String
    let content: String
    let published: NSDate
    let updated: NSDate?

    var authors: [FakeImportableAuthor]

    var importableAuthors: [ImportableAuthor] {
        return self.authors.map { $0 as ImportableAuthor }
    }

    init(title: String, url: NSURL, summary: String, content: String, published: NSDate, updated: NSDate?, authors: [FakeImportableAuthor] = []) {
        self.title = title
        self.url = url
        self.summary = summary
        self.content = content
        self.published = published
        self.updated = updated
        self.authors = authors
    }
}

struct FakeImportableAuthor: ImportableAuthor {
    let name: String
    let email: NSURL?

    init(name: String, email: NSURL?) {
        self.name = name
        self.email = email
    }
}
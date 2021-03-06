import Muon

protocol ImportableFeed {
    var title: String { get }
    var url: URL? { get }
    var description: String { get }
    var imageURL: URL? { get }
    var lastUpdated: Date { get }
    var importableArticles: [ImportableArticle] { get }
}

protocol ImportableArticle {
    var title: String { get }
    var url: URL? { get }
    var summary: String { get }
    var content: String { get }
    var published: Date { get }
    var updated: Date? { get }
    var read: Bool { get }
    var importableAuthors: [ImportableAuthor] { get }
}

protocol ImportableAuthor {
    var name: String { get }
    var email: URL? { get }
}
// MARK: Muon conformance
extension Muon.Feed: ImportableFeed {
    var url: URL? {
        return self.link
    }

    var importableArticles: [ImportableArticle] {
        return self.articles.map { $0 as ImportableArticle }
    }

    var lastUpdated: Date {
        return Date()
    }
}
extension Muon.Article: ImportableArticle {
    var url: URL? {
        return self.link ?? URL(string: self.guid ?? "")
    }

    var summary: String {
        return self.description
    }

    var read: Bool {
        return false
    }

    var importableAuthors: [ImportableAuthor] {
        return self.authors.map { $0 as ImportableAuthor }
    }
}
extension Muon.Author: ImportableAuthor {}

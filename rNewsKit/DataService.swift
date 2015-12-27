import Foundation
import Muon
#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif

/**
 Basic protocol describing the service that interacts with the network and database levels.

 Everything is asynchronous, though depending upon the underlying service, they may turn out to be asynchronous.
*/
protocol DataService: class {
    func createFeed(callback: (Feed) -> (Void))
    func createArticle(feed: Feed?, callback: (Article) -> (Void))
    func createEnclosure(article: Article?, callback: (Enclosure) -> (Void))

    func feedsMatchingPredicate(predicate: NSPredicate, callback: [Feed] -> Void)
    func articlesMatchingPredicate(predicate: NSPredicate, callback: [Article] -> Void)
    func enclosuresMatchingPredicate(predicate: NSPredicate, callback: [Enclosure] -> Void)

    func saveFeed(feed: Feed, callback: (Void) -> (Void))
    func saveArticle(article: Article, callback: (Void) -> (Void))
    func saveEnclosure(enclosure: Enclosure, callback: (Void) -> (Void))

    func deleteFeed(feed: Feed, callback: (Void) -> (Void))
    func deleteArticle(article: Article, callback: (Void) -> (Void))
    func deleteEnclosure(enclosure: Enclosure, callback: (Void) -> (Void))
}

extension DataService {
    func updateFeed(feed: Feed, info: Muon.Feed, callback: (Void) -> (Void)) {
        let summary: String
        let data = info.description.dataUsingEncoding(NSUTF8StringEncoding,
            allowLossyConversion: false)!
        let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
        do {
            let aString = try NSAttributedString(data: data, options: options,
                documentAttributes: nil)
            summary = aString.string
        } catch _ {
            summary = info.description
        }

        feed.title = info.title
        feed.summary = summary

        self.saveFeed(feed, callback: callback)
    }

    func updateArticle(article: Article, item: Muon.Article, callback: (Void) -> (Void)) {
        let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        let author = item.authors.map({ author in
            if let email = author.email?.resourceSpecifier {
                return "\(author.name) <\(email)>"
            }
            return author.name
        }).joinWithSeparator(", ")

        article.title = (item.title ?? article.title ?? "unknown").stringByTrimmingCharactersInSet(characterSet)
        article.link = item.link
        article.published = item.published ?? article.published
        article.updatedAt = item.updated
        article.summary = item.description ?? ""
        article.content = item.content ?? ""

        article.author = author

        self.saveArticle(article, callback: callback)
    }

    func upsertEnclosureForArticle(article: Article, fromItem item: Muon.Enclosure, callback: (Enclosure) -> (Void)) {
        let url = item.url
        for enclosure in article.enclosuresArray {
            if enclosure.url == url {
                enclosure.kind = item.type
                self.saveEnclosure(enclosure) { callback(enclosure) }
                return
            }
        }
        self.createEnclosure(article) {enclosure in
            enclosure.url = url
            enclosure.kind = item.type
            enclosure.article = article
            callback(enclosure)
        }
    }
}

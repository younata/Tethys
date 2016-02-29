import Foundation
import Muon
#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
    import CoreSpotlight
    import MobileCoreServices
#endif

/**
 Basic protocol describing the service that interacts with the network and database levels.

 Everything is asynchronous, though depending upon the underlying service, they may turn out to be asynchronous.
 All callbacks must be done on the main queue.
*/
protocol DataService: class {
    var searchIndex: SearchIndex? { get }
    var mainQueue: NSOperationQueue { get }

    func createFeed(callback: Feed -> Void)
    func createArticle(feed: Feed?, callback: Article -> Void)
    func createEnclosure(article: Article?, callback: Enclosure -> Void)

    func feedsMatchingPredicate(predicate: NSPredicate, callback: [Feed] -> Void)
    func articlesMatchingPredicate(predicate: NSPredicate, callback: [Article] -> Void)
    func enclosuresMatchingPredicate(predicate: NSPredicate, callback: [Enclosure] -> Void)

    func saveFeed(feed: Feed, callback: Void -> Void)
    func saveArticle(article: Article, callback: Void -> Void)
    func saveEnclosure(enclosure: Enclosure, callback: Void -> Void)

    func deleteFeed(feed: Feed, callback: Void -> Void)
    func deleteArticle(article: Article, callback: Void -> Void)
    func deleteEnclosure(enclosure: Enclosure, callback: Void -> Void)
}

extension DataService {
    func allFeeds(callback: [Feed] -> Void) {
        self.feedsMatchingPredicate(NSPredicate(value: true), callback: callback)
    }

    func updateFeed(feed: Feed, info: Muon.Feed, callback: Void -> Void) {
        feed.title = info.title.stringByUnescapingHTML().stringByStrippingHTML()
        feed.summary = info.description

        let articles = info.articles.filter { $0.title?.isEmpty == false }

        if articles.isEmpty {
            self.saveFeed(feed, callback: callback)
            return
        }

        var articlesRemaining = articles.count

        let checkIfFinished = {
            articlesRemaining -= 1
            if articlesRemaining == 0 {
                self.saveFeed(feed, callback: callback)
            }
        }

        for item in articles {
            let article = feed.articlesArray.filter { article in
                return item.title == article.title || item.link == article.link
            }.first
            self.mainQueue.addOperationWithBlock {
                if let article = article {
                    self.updateArticle(article, item: item, feedURL: info.link, callback: checkIfFinished)
                } else {
                    self.createArticle(feed) { article in
                        feed.addArticle(article)
                        self.updateArticle(article, item: item, feedURL: info.link, callback: checkIfFinished)
                    }
                }
            }
        }
    }

    func updateArticle(article: Article, item: Muon.Article, feedURL: NSURL, callback: Void -> Void) {
        let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        let author = item.authors.map({ author in
            if let email = author.email?.resourceSpecifier {
                return "\(author.name) <\(email)>"
            }
            return author.name
        }).joinWithSeparator(", ")

        let title = (item.title ?? article.title ?? "unknown").stringByTrimmingCharactersInSet(characterSet)
        article.title = title.stringByUnescapingHTML().stringByStrippingHTML()
        article.link = NSURL(string: item.link?.absoluteString ?? "", relativeToURL: feedURL)?.absoluteURL
        article.published = item.published ?? article.published
        article.updatedAt = item.updated
        article.summary = item.description ?? ""
        article.content = item.content ?? ""

        article.estimatedReadingTime = estimateReadingTime(item.content ?? item.description ?? "")

        article.author = author

        for enclosure in item.enclosures {
            self.upsertEnclosureForArticle(article, fromItem: enclosure)
        }

        let content = item.content ?? item.description ?? ""
        let parser = WebPageParser(string: content) { urls in
            let links = urls.flatMap { NSURL(string: $0.absoluteString, relativeToURL: feedURL)?.absoluteString }
            self.articlesMatchingPredicate(NSPredicate(format: "link IN %@", links)) { related in
                related.forEach(article.addRelatedArticle)
                self.saveArticle(article) {
                    callback()
                }
            }
        }
        parser.searchType = .Links
        parser.start()
    }

    func updateSearchIndexForArticle(article: Article) {
        #if os(iOS)
            if #available(iOS 9.0, *) {
                let identifier = article.identifier

                let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeHTML as String)
                attributes.title = article.title
                let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
                let trimmedSummary = article.summary.stringByTrimmingCharactersInSet(characterSet)
                attributes.contentDescription = trimmedSummary
                let feedTitleWords = article.feed?.title.componentsSeparatedByCharactersInSet(characterSet)
                attributes.keywords = ["article"] + (feedTitleWords ?? [])
                attributes.URL = article.link
                attributes.timestamp = article.updatedAt ?? article.published
                attributes.authorNames = [article.author]

                if let image = article.feed?.image, let data = UIImagePNGRepresentation(image) {
                    attributes.thumbnailData = data
                }

                let item = CSSearchableItem(uniqueIdentifier: identifier,
                    domainIdentifier: nil,
                    attributeSet: attributes)
                item.expirationDate = NSDate.distantFuture()
                self.searchIndex?.addItemsToIndex([item]) {_ in }
            }
        #endif
    }

    func upsertEnclosureForArticle(article: Article, fromItem item: Muon.Enclosure) {
        let url = item.url
        for enclosure in article.enclosuresArray {
            if enclosure.url == url {
                enclosure.kind = item.type
                self.saveEnclosure(enclosure) { }
                return
            }
        }
        self.createEnclosure(article) {enclosure in
            enclosure.url = url
            enclosure.kind = item.type
        }
    }
}

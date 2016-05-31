import Foundation
import Muon
import CBGPromise
import Result
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

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, RNewsError>>
    func articlesMatchingPredicate(predicate: NSPredicate) -> Future<Result<DataStoreBackedArray<Article>, RNewsError>>

    func deleteFeed(feed: Feed) -> Future<Result<Void, RNewsError>>
    func deleteArticle(article: Article) -> Future<Result<Void, RNewsError>>

    func batchCreate(feedCount: Int, articleCount: Int, enclosureCount: Int) ->
        Future<Result<([Feed], [Article], [Enclosure]), RNewsError>>
    func batchSave(feeds: [Feed], articles: [Article], enclosures: [Enclosure]) -> Future<Result<Void, RNewsError>>

    func deleteEverything() -> Future<Result<Void, RNewsError>>
}

extension DataService {
    func saveFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        return self.batchSave([feed], articles: [], enclosures: [])
    }

    func updateFeed(feed: Feed, info: Muon.Feed) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        feed.title = info.title.stringByUnescapingHTML().stringByStrippingHTML()
        feed.summary = info.description

        let articles: [Muon.Article] = info.articles.filter { $0.title?.isEmpty == false }

        if articles.isEmpty {
            return self.saveFeed(feed)
        }

        var articlesToSave: [Article] = []
        var enclosuresToSave: [Enclosure] = []

        var importTasks: [Void -> Void] = []

        let checkIfFinished: Result<(Article, [Enclosure]), RNewsError> -> Void = { result in
            switch result {
            case let .Success(article, enclosures):
                articlesToSave.append(article)
                enclosuresToSave += enclosures
                if importTasks.isEmpty {
                    self.batchSave([feed], articles: articlesToSave, enclosures: enclosures).then { _ in
                        promise.resolve(.Success())
                    }
                } else {
                    importTasks.popLast()?()
                }
            case let .Failure(error):
                promise.resolve(.Failure(error))
                return
            }
        }

        for item in articles {
            importTasks.append {
                let filter: rNewsKit.Article -> Bool = { article in
                    return item.title == article.title || item.link == article.link
                }
                let article = feed.articlesArray.filter(filter).first
                if let article = article ?? articlesToSave.filter(filter).first {
                    self.updateArticle(article, item: item, feedURL: info.link).then(checkIfFinished)
                } else {
                    self.createArticle(feed) { article in
                        feed.addArticle(article)
                        self.updateArticle(article, item: item, feedURL: info.link).then(checkIfFinished)
                    }
                }
            }
        }

        if let task = importTasks.popLast() {
            task()
        } else {
            let result = Result<Void, RNewsError>(value: ())
            promise.resolve(result)
        }
        return promise.future
    }

    func updateArticle(article: Article, item: Muon.Article, feedURL: NSURL) ->
        Future<Result<(Article, [Enclosure]), RNewsError>> {
            let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
            let authors = item.authors.map {
                return rNewsKit.Author(name: $0.name, email: $0.email)
            }

            let title = (item.title ?? article.title ?? "unknown").stringByTrimmingCharactersInSet(characterSet)
            article.title = title.stringByUnescapingHTML().stringByStrippingHTML()
            article.link = NSURL(string: item.link?.absoluteString ?? "", relativeToURL: feedURL)?.absoluteURL
            article.published = item.published ?? article.published
            article.updatedAt = item.updated
            article.summary = item.description ?? ""
            article.content = item.content ?? ""

            article.estimatedReadingTime = estimateReadingTime(item.content ?? item.description ?? "")

            article.authors = authors

            let enclosures: [Enclosure] = item.enclosures.flatMap {
                if let result = self.upsertEnclosureForArticle(article, fromItem: $0).wait() {
                    return result
                }
                return nil
            }

            let content = item.content ?? item.description ?? ""

            let promise = Promise<Result<(Article, [Enclosure]), RNewsError>>()

            let parser = WebPageParser(string: content) { urls in
                let links = urls.flatMap { NSURL(string: $0.absoluteString, relativeToURL: feedURL)?.absoluteString }
                self.articlesMatchingPredicate(NSPredicate(format: "link IN %@", links)).then { result in
                    switch result {
                    case let .Success(related):
                        related.forEach(article.addRelatedArticle)
                        promise.resolve(.Success(article, enclosures))
                    case let .Failure(error):
                        promise.resolve(.Failure(error))
                    }
                }
            }
            parser.searchType = .Links
            parser.start()
            return promise.future
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
                attributes.authorNames = article.authors.map { $0.name }

                if let image = article.feed?.image, data = UIImagePNGRepresentation(image) {
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

    func upsertEnclosureForArticle(article: Article, fromItem item: Muon.Enclosure) -> Future<Enclosure?> {
            let promise = Promise<Enclosure?>()

            let url = item.url
            for enclosure in article.enclosuresArray where enclosure.url == url {
                if enclosure.kind != item.type {
                    enclosure.kind = item.type
                    promise.resolve(enclosure)
                } else {
                    promise.resolve(nil)
                }
                return promise.future
            }
            self.createEnclosure(article) {enclosure in
                enclosure.url = url
                enclosure.kind = item.type
            }
            promise.resolve(nil)
            return promise.future
    }
}

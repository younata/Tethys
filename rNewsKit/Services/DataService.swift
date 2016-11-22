import Foundation
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
    var mainQueue: OperationQueue { get }

    func createFeed(url: URL, callback: @escaping (Feed) -> Void) -> Future<Result<Feed, RNewsError>>
    func createArticle(url: URL, feed: Feed?, callback: @escaping (Article) -> Void)

    func findOrCreateFeed(url: URL) -> Future<Feed>
    func findOrCreateArticle(feed: Feed, url: URL) -> Future<Article>

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, RNewsError>>
    func articlesMatchingPredicate(_ predicate: NSPredicate) ->
        Future<Result<DataStoreBackedArray<Article>, RNewsError>>

    func deleteFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>>
    func deleteArticle(_ article: Article) -> Future<Result<Void, RNewsError>>

    func batchCreate(feedURLs: [URL], articleURLs: [URL]) ->
        Future<Result<([Feed], [Article]), RNewsError>>
    func batchSave(_ feeds: [Feed], articles: [Article]) -> Future<Result<Void, RNewsError>>

    func deleteEverything() -> Future<Result<Void, RNewsError>>
}

extension DataService {
    func saveFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>> {
        return self.batchSave([feed], articles: [])
    }

    func updateFeed(_ feed: Feed, info: ImportableFeed) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        feed.title = info.title.stringByUnescapingHTML().stringByStrippingHTML()
        feed.summary = info.description
        feed.lastUpdated = info.lastUpdated

        let articles: [ImportableArticle] = info.importableArticles.filter { $0.title.isEmpty == false }

        if articles.isEmpty {
            return self.saveFeed(feed)
        }

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .utility
        operationQueue.maxConcurrentOperationCount = 1

        for item in articles {
            operationQueue.addOperation {
                _ = self.findOrCreateArticle(feed: feed, url: item.url).map { article in
                    return self.updateArticle(article, item: item, feedURL: info.url).map { _ in
                        return self.batchSave([feed], articles: [article])
                    }
                }.wait()
            }
        }

        let saveOperation = BlockOperation {
            promise.resolve(.success())
        }
        operationQueue.addOperation(saveOperation)

        return promise.future
    }

    func updateArticle(_ article: Article, item: ImportableArticle, feedURL: URL) ->
        Future<Result<Article, RNewsError>> {
            let characterSet = CharacterSet.whitespacesAndNewlines
            let authors = item.importableAuthors.map {
                return rNewsKit.Author(name: $0.name, email: $0.email)
            }

            let itemTitle: String
            if item.title.isEmpty {
                if article.title.isEmpty {
                    itemTitle = "unknown"
                } else {
                    itemTitle = article.title
                }
            } else {
                itemTitle = item.title
            }
            let title = (itemTitle).trimmingCharacters(in: characterSet)
            article.title = title.stringByUnescapingHTML().stringByStrippingHTML()
            article.link = URL(string: item.url.absoluteString, relativeTo: feedURL)!.absoluteURL
            article.published = item.published
            article.updatedAt = item.updated
            article.summary = item.summary
            article.content = item.content

            let content = item.content.isEmpty ? item.summary : item.content
            article.estimatedReadingTime = estimateReadingTime(content)

            article.authors = authors

            let promise = Promise<Result<Article, RNewsError>>()

            let parser = WebPageParser(string: content) { urls in
                let links = urls.flatMap { URL(string: $0.absoluteString, relativeTo: feedURL)?.absoluteString }
                _ = self.articlesMatchingPredicate(NSPredicate(format: "link IN %@", links)).then { result in
                    switch result {
                    case let .success(related):
                        related.forEach(article.addRelatedArticle)
                        promise.resolve(.success(article))
                    case let .failure(error):
                        promise.resolve(.failure(error))
                    }
                }
            }
            parser.searchType = .links
            parser.start()
            return promise.future
    }

    func updateSearchIndexForArticle(_ article: Article) {
        #if os(iOS)
            let identifier = article.identifier

            let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeHTML as String)
            attributes.title = article.title
            let characterSet = CharacterSet.whitespacesAndNewlines
            let trimmedSummary = article.summary.trimmingCharacters(in: characterSet)
            attributes.contentDescription = trimmedSummary
            let feedTitleWords = article.feed?.title.components(separatedBy: characterSet)
            attributes.keywords = ["article"] + (feedTitleWords ?? [])
            attributes.url = article.link
            attributes.timestamp = (article.updatedAt ?? article.published) as Date
            attributes.authorNames = article.authors.map { $0.name }

            if let image = article.feed?.image, let data = UIImagePNGRepresentation(image) {
                attributes.thumbnailData = data
            }

            let item = CSSearchableItem(uniqueIdentifier: identifier,
                                        domainIdentifier: nil,
                                        attributeSet: attributes)
            item.expirationDate = Date.distantFuture
            self.searchIndex?.addItemsToIndex([item]) {_ in }
        #endif
    }
}

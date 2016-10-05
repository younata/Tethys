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

    func createFeed(_ callback: @escaping (Feed) -> Void) -> Future<Result<Feed, RNewsError>>
    func createArticle(_ feed: Feed?, callback: @escaping (Article) -> Void)

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, RNewsError>>
    func articlesMatchingPredicate(_ predicate: NSPredicate) ->
        Future<Result<DataStoreBackedArray<Article>, RNewsError>>

    func deleteFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>>
    func deleteArticle(_ article: Article) -> Future<Result<Void, RNewsError>>

    func batchCreate(_ feedCount: Int, articleCount: Int) ->
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

        var articlesToSave: [Article] = []

        let checkIfFinished: (Result<(Article), RNewsError>) -> Void = { result in
            if case let .success(article) = result {
                articlesToSave.append(article)
            }
        }

        let articleUrls = articles.flatMap { $0.url.absoluteString }
        let articleTitles = articles.map { $0.title }
        let articlesPredicate = NSPredicate(format: "link IN %@ OR title IN %@", articleUrls, articleTitles)
        let feedArticles = Array(feed.articlesArray.filterWithPredicate(articlesPredicate))

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .utility
        operationQueue.maxConcurrentOperationCount = 1

        for item in articles {
            let filter: (rNewsKit.Article) -> Bool = { article in
                return item.url == article.link
            }
            let article = feedArticles.objectPassingTest(filter)
            operationQueue.addOperation {
                if let article = article ?? articlesToSave.objectPassingTest(filter) {
                    _ = self.updateArticle(article, item: item, feedURL: info.url).then(callback: checkIfFinished)
                } else {
                    self.createArticle(feed) { article in
                        _ = self.updateArticle(article, item: item, feedURL: info.url).then(callback: checkIfFinished)
                    }
                }
            }
        }

        let saveOperation = BlockOperation {
            _ = self.batchSave([feed], articles: articlesToSave).then { _ in
                promise.resolve(.success())
            }
        }
        operationQueue.operations.forEach { saveOperation.addDependency($0) }
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
            article.link = URL(string: item.url.absoluteString, relativeTo: feedURL)?.absoluteURL
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

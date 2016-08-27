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
    var mainQueue: NSOperationQueue { get }

    func createFeed(callback: Feed -> Void) -> Future<Result<Feed, RNewsError>>
    func createArticle(feed: Feed?, callback: Article -> Void)

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, RNewsError>>
    func articlesMatchingPredicate(predicate: NSPredicate) -> Future<Result<DataStoreBackedArray<Article>, RNewsError>>

    func deleteFeed(feed: Feed) -> Future<Result<Void, RNewsError>>
    func deleteArticle(article: Article) -> Future<Result<Void, RNewsError>>

    func batchCreate(feedCount: Int, articleCount: Int) ->
        Future<Result<([Feed], [Article]), RNewsError>>
    func batchSave(feeds: [Feed], articles: [Article]) -> Future<Result<Void, RNewsError>>

    func deleteEverything() -> Future<Result<Void, RNewsError>>
}

extension DataService {
    func saveFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        return self.batchSave([feed], articles: [])
    }

    func updateFeed(feed: Feed, info: ImportableFeed) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        feed.title = info.title.stringByUnescapingHTML().stringByStrippingHTML()
        feed.summary = info.description

        let articles: [ImportableArticle] = info.importableArticles.filter { $0.title.isEmpty == false }

        if articles.isEmpty {
            return self.saveFeed(feed)
        }

        var articlesToSave: [Article] = []

        let articleUrls = articles.flatMap { $0.url.absoluteString }
        let articlesPredicate = NSPredicate(format: "link IN %@", articleUrls)
        let feedArticles = Array(feed.articlesArray.filterWithPredicate(articlesPredicate))

        let operationQueue = NSOperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        var articlesToCreate: [ImportableArticle] = []

        for item in articles {
            let filter: rNewsKit.Article -> Bool = { article in
                return item.title == article.title || item.url == article.link
            }
            let article = feedArticles.objectPassingTest(filter)
            operationQueue.addOperationWithBlock {
                if let article = article ?? articlesToSave.objectPassingTest(filter) {
                    self.updateArticle(article, item: item, feedURL: info.link).then { _ in
                        articlesToSave.append(article)
                    }.wait()
                } else {
                    articlesToCreate.append(item)
                }
            }
        }

        operationQueue.waitUntilAllOperationsAreFinished()

        self.batchCreate(0, articleCount: articlesToCreate.count).then { res in
            if case let .Success(_, createdArticles) = res {
                for (idx, article) in createdArticles.enumerate() {
                    operationQueue.addOperationWithBlock {
                        feed.addArticle(article)
                        let item = articlesToCreate[idx]
                        self.updateArticle(article, item: item, feedURL: info.link).then { _ in
                            articlesToSave.append(article)
                        }.wait()
                    }
                }
            }
        }.wait()

        operationQueue.waitUntilAllOperationsAreFinished()

        self.batchSave([feed], articles: articlesToSave).then { _ in
            promise.resolve(.Success())
        }
        return promise.future
    }

    func updateArticle(article: Article, item: ImportableArticle, feedURL: NSURL) ->
        Future<Result<Article, RNewsError>> {
            let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
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
            let title = (itemTitle).stringByTrimmingCharactersInSet(characterSet)
            article.title = title.stringByUnescapingHTML().stringByStrippingHTML()
            article.link = NSURL(string: item.url.absoluteString, relativeToURL: feedURL)?.absoluteURL
            article.published = item.published ?? article.published
            article.updatedAt = item.updated
            article.summary = item.summary
            article.content = item.content

            let content = item.content.isEmpty ? item.summary : item.content
            article.estimatedReadingTime = estimateReadingTime(content)

            article.authors = authors

            let promise = Promise<Result<Article, RNewsError>>()

            let parser = WebPageParser(string: content) { urls in
                let links = urls.flatMap { NSURL(string: $0.absoluteString, relativeToURL: feedURL)?.absoluteString }
                self.articlesMatchingPredicate(NSPredicate(format: "link IN %@", links)).then { result in
                    switch result {
                    case let .Success(related):
                        related.forEach(article.addRelatedArticle)
                        promise.resolve(.Success(article))
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
        #endif
    }
}

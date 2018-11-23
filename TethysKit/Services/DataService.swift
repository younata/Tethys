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

    func createFeed(url: URL, callback: @escaping (Feed) -> Void) -> Future<Result<Feed, TethysError>>
    func createArticle(url: URL, feed: Feed?, callback: @escaping (Article) -> Void)

    func findOrCreateFeed(url: URL) -> Future<Feed>
    func findOrCreateArticle(feed: Feed, url: URL) -> Future<Article>

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, TethysError>>
    func articlesMatchingPredicate(_ predicate: NSPredicate) ->
        Future<Result<DataStoreBackedArray<Article>, TethysError>>

    func deleteFeed(_ feed: Feed) -> Future<Result<Void, TethysError>>
    func deleteArticle(_ article: Article) -> Future<Result<Void, TethysError>>

    func batchCreate(feedURLs: [URL], articleURLs: [URL]) ->
        Future<Result<([Feed], [Article]), TethysError>>
    func batchSave(_ feeds: [Feed], articles: [Article]) -> Future<Result<Void, TethysError>>

    func deleteEverything() -> Future<Result<Void, TethysError>>
}

extension DataService {
    func saveFeed(_ feed: Feed) -> Future<Result<Void, TethysError>> {
        return self.batchSave([feed], articles: [])
    }

    private func absoluteURLForArticle(article: ImportableArticle, feedURL: URL) -> String {
        var urlComponents = URLComponents(url: URL(string: article.url.absoluteString, relativeTo: feedURL)!,
                                          resolvingAgainstBaseURL: true)!
        if urlComponents.scheme == "http" {
            urlComponents.scheme = "https"
        }
        return urlComponents.url!.absoluteString
    }

    func updateFeed(_ feed: Feed, info: ImportableFeed) -> Future<Result<Void, TethysError>> {
        feed.title = info.title.stringByUnescapingHTML().stringByStrippingHTML()
        feed.summary = info.description
        feed.lastUpdated = info.lastUpdated

        let articles: [ImportableArticle] = info.importableArticles.filter {
            return $0.title.isEmpty == false
        }.reduce([]) { articles, article in
            let articleURLs = articles.map { self.absoluteURLForArticle(article: $0, feedURL: info.url) }
            let articleURL = self.absoluteURLForArticle(article: article, feedURL: info.url)
            if articleURLs.contains(articleURL) {
                return articles
            }
            return articles + [article]
        }

        if articles.isEmpty {
            return self.saveFeed(feed)
        }

        let futures: [Future<Article>] = articles.map { item in
            return self.findOrCreateArticle(feed: feed, url: item.url).then { article in
                self.updateArticle(article, item: item, feedURL: info.url)
            }
        }

        return Promise<Article>.Tethys_when(futures).map { (articles: [Article]) -> Future<Result<Void, TethysError>> in
            self.batchSave([feed], articles: articles)
        }
    }

    func updateArticle(_ article: Article, item: ImportableArticle, feedURL: URL) {
        let characterSet = CharacterSet.whitespacesAndNewlines
        let authors = item.importableAuthors.map {
            return TethysKit.Author(name: $0.name, email: $0.email)
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
        if article.read && !item.read {
            article.synced = false
        } else {
            article.read = item.read
            article.synced = true
        }
        article.authors = authors
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

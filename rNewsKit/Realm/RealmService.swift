import RealmSwift
import Foundation
import CBGPromise
import Result

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

final class RealmService: DataService {
    private let realmConfiguration: Realm.Configuration

    let mainQueue: OperationQueue
    let workQueue: OperationQueue
    let searchIndex: SearchIndex?

    init(realmConfiguration: Realm.Configuration,
        mainQueue: OperationQueue,
        workQueue: OperationQueue,
        searchIndex: SearchIndex?) {
            self.realmConfiguration = realmConfiguration
            self.mainQueue = mainQueue
            self.workQueue = workQueue
            self.searchIndex = searchIndex
    }

    private var realmsForThreads: [Thread: Realm] = [:]
    private var realm: Realm {
        let thread = Thread.current
        if let realm = self.realmsForThreads[thread] {
            return realm
        }

        // swiftlint:disable force_try
        let realm = try! Realm(configuration: self.realmConfiguration)
        // swiftlint:enable force_try
        self.realmsForThreads[thread] = realm

        return realm
    }

    func createFeed(url: URL, callback: @escaping (Feed) -> (Void)) -> Future<Result<Feed, RNewsError>> {
        let promise = Promise<Result<Feed, RNewsError>>()
        _ = self.realmTransaction {
            let realmFeed = self.realm.create(RealmFeed.self, value: ["url": url.absoluteString])
            let feed = Feed(realmFeed: realmFeed)

            let operation = BlockOperation { callback(feed) }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.synchronousUpdateFeed(feed, realmFeed: realmFeed)
            _ = try? self.realm.commitWrite()

            promise.resolve(.success(feed))
        }
        return promise.future
    }

    func createArticle(url: URL, feed: Feed?, callback: @escaping (Article) -> (Void)) {
        _ = self.realmTransaction {
            let realmArticle = self.realm.create(RealmArticle.self, value: ["link": url.absoluteString])
            let article = Article(realmArticle: realmArticle, feed: feed)
            feed?.addArticle(article)

            let operation = BlockOperation { callback(article) }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.synchronousUpdateArticle(article, realmArticle: realmArticle)
            _ = try? self.realm.commitWrite()
        }
    }

    // must be called from within a realmTransaction!
    private func privateFindOrCreateRealmFeed(url: URL) -> RealmFeed {
        let feed: RealmFeed
        if let realmFeed = self.realm.objects(RealmFeed.self).filter("url = %@", url.absoluteString).first {
            feed = realmFeed
        } else {
            feed = self.realm.create(RealmFeed.self, value: ["url": url.absoluteString])
        }
        return feed
    }

    func findOrCreateFeed(url: URL) -> Future<Feed> {
        let promise = Promise<Feed>()
        _ = self.realmTransaction {
            promise.resolve(Feed(realmFeed: self.privateFindOrCreateRealmFeed(url: url)))
        }
        return promise.future
    }

    func findOrCreateArticle(feed: Feed, url: URL) -> Future<Article> {
        let promise = Promise<String>()
        _ = self.realmTransaction {
            if let realmFeed = self.realmFeedForFeed(feed) {
                let article: Article

                let httpsURLString: String
                let httpURLString: String

                var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if urlComponents?.scheme == "http" {
                    httpURLString = url.absoluteString
                    urlComponents?.scheme = "https"
                    httpsURLString = urlComponents?.url?.absoluteString ?? url.absoluteString
                } else if urlComponents?.scheme == "https" {
                    httpsURLString = url.absoluteString
                    urlComponents?.scheme = "http"
                    httpURLString = urlComponents?.url?.absoluteString ?? url.absoluteString
                } else {
                    httpURLString = url.absoluteString
                    httpsURLString = url.absoluteString
                }

                if let realmArticle = self.realm.objects(RealmArticle.self)
                    .filter("feed.id = %@ AND (link = %@ OR link = %@)",
                            realmFeed.id, httpsURLString, httpURLString).first {
                    promise.resolve(realmArticle.id)
                } else {
                    let realmArticle = self.realm.create(RealmArticle.self, value: ["link": url.absoluteString])
                    article = Article(realmArticle: realmArticle, feed: feed)
                    feed.addArticle(article)
                    self.synchronousUpdateArticle(article, realmArticle: realmArticle)
                    _ = try? self.realm.commitWrite()
                    promise.resolve(realmArticle.id)
                }
            } else {
                let realmFeed = self.privateFindOrCreateRealmFeed(url: feed.url)
                let realmArticle = self.realm.create(RealmArticle.self, value: ["link": url.absoluteString])
                self.synchronousUpdateFeed(feed, realmFeed: realmFeed)
                let article = Article(realmArticle: realmArticle, feed: feed)
                feed.addArticle(article)
                self.synchronousUpdateArticle(article, realmArticle: realmArticle)
                _ = try? self.realm.commitWrite()
                promise.resolve(realmArticle.id)
            }
        }
        return promise.future.map { id -> Article in
            let realmArticle = self.realm.object(ofType: RealmArticle.self, forPrimaryKey: id)!
            return Article(realmArticle: realmArticle, feed: feed)
        }
    }

    // Mark: - Read

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, RNewsError>> {
        let promise = Promise<Result<DataStoreBackedArray<Feed>, RNewsError>>()
        let sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

        let feeds = DataStoreBackedArray(realmDataType: RealmFeed.self,
            predicate: NSPredicate(value: true),
            realmConfiguration: self.realmConfiguration,
            conversionFunction: { Feed(realmFeed: $0 as! RealmFeed) },
            sortDescriptors: sortDescriptors)
        promise.resolve(.success(feeds))
        return promise.future
    }

    func articlesMatchingPredicate(_ predicate: NSPredicate) ->
        Future<Result<DataStoreBackedArray<Article>, RNewsError>> {
            let promise = Promise<Result<DataStoreBackedArray<Article>, RNewsError>>()
            let sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(key: "published", ascending: false)
            ]

            let articles = DataStoreBackedArray(realmDataType: RealmArticle.self,
                predicate: predicate,
                realmConfiguration: self.realmConfiguration,
                conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) },
                sortDescriptors: sortDescriptors)
            promise.resolve(.success(articles))
            return promise.future
    }

    // Mark: - Delete

    func deleteFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        let articleIdentifiers = feed.articlesArray.map { $0.identifier }
        #if os(iOS)
            self.searchIndex?.deleteIdentifierFromIndex(articleIdentifiers) {_ in }
        #endif
        _ = self.realmTransaction {
            self.synchronousDeleteFeed(feed)
        }.then {
            self.mainQueue.addOperation {
                promise.resolve(.success())
            }
        }
        return promise.future
    }

    func deleteArticle(_ article: Article) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        #if os(iOS)
            self.searchIndex?.deleteIdentifierFromIndex([article.identifier]) {_ in }
        #endif
        _ = self.realmTransaction {
            self.synchronousDeleteArticle(article)
        }.then {
            self.mainQueue.addOperation {
                promise.resolve(.success())
            }
        }
        return promise.future
    }

    // Mark: - Batch

    func batchCreate(feedURLs: [URL], articleURLs: [URL]) ->
        Future<Result<([Feed], [Article]), RNewsError>> {
            let promise = Promise<Result<([Feed], [Article]), RNewsError>>()
            _ = self.realmTransaction {
                let realmFeeds = feedURLs.map {
                    return self.realm.create(RealmFeed.self, value: ["url": $0.absoluteString])
                }
                let realmArticles = articleURLs.map {
                    return self.realm.create(RealmArticle.self, value: ["link": $0.absoluteString])
                }

                let feeds = realmFeeds.map(Feed.init)
                let articles = realmArticles.map { Article(realmArticle: $0, feed: nil) }

                self.mainQueue.addOperation {
                    promise.resolve(.success(feeds, articles))
                }
            }
            return promise.future
    }

    func batchSave(_ feeds: [Feed], articles: [Article]) -> Future<Result<Void, RNewsError>> {
        return self.realmTransaction {
            articles.forEach { self.synchronousUpdateArticle($0) }
            feeds.forEach { self.synchronousUpdateFeed($0) }
            _ = try? self.realm.commitWrite()
        }.map {
            return .success()
        }
    }

    func deleteEverything() -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        _ = self.realmTransaction {
            self.realm.deleteAll()

            self.mainQueue.addOperation {
                promise.resolve(.success())
            }
        }
        return promise.future
    }

    // Mark: - Private

    private func realmFeedForFeed(_ feed: Feed) -> RealmFeed? {
        guard let feedID = feed.feedID as? String else { return nil }
        return self.realm.object(ofType: RealmFeed.self, forPrimaryKey: feedID as AnyObject)
    }

    private func realmStringForString(_ string: String) -> RealmString? {
        let predicate = NSPredicate(format: "string = %@", string)
        return self.realm.objects(RealmString.self).filter(predicate).first
    }

    private func realmArticleForArticle(_ article: Article) -> RealmArticle? {
        guard let articleID = article.articleID as? String else { return nil }
        return self.realm.object(ofType: RealmArticle.self, forPrimaryKey: articleID as AnyObject)
    }

    private func realmAuthorForAuthor(_ author: Author) -> RealmAuthor? {
        let predicate = NSPredicate(format: "name = %@ AND email = %@", author.name, author.email?.absoluteString ?? "")
        return self.realm.objects(RealmAuthor.self).filter(predicate).first
    }

    // Synchronous update!

    private func synchronousUpdateFeed(_ feed: Feed, realmFeed: RealmFeed? = nil) {
        guard feed.updated else { return }
        self.startRealmTransaction()

        if let rfeed = realmFeed ?? self.realmFeedForFeed(feed) {
            rfeed.title = feed.title
            rfeed.url = feed.url.absoluteString
            rfeed.summary = feed.summary
            let tags: [RealmString] = feed.tags.map { str in
                let realmString = self.realmStringForString(str) ?? RealmString()
                realmString.string = str
                return realmString
            }
            rfeed.tags.replaceSubrange(0..<rfeed.tags.count, with: tags)
            rfeed.waitPeriod = feed.waitPeriod
            rfeed.remainingWait = feed.remainingWait
            rfeed.lastUpdated = feed.lastUpdated
            #if os(iOS)
                if let image = feed.image {
                    rfeed.imageData = UIImagePNGRepresentation(image)
                }
            #else
                if let image = feed.image {
                    rfeed.imageData = image.tiffRepresentation
                }
            #endif
        }
        feed.resetArticles(realm: self.realm)
    }

    private func synchronousUpdateArticle(_ article: Article, realmArticle: RealmArticle? = nil) {
        guard article.updated else { return }
        self.startRealmTransaction()

        if let rarticle = realmArticle ?? self.realmArticleForArticle(article) {
            rarticle.title = article.title
            rarticle.link = article.link.absoluteString
            rarticle.summary = article.summary
            let authors: [RealmAuthor] = article.authors.map {
                let author = self.realmAuthorForAuthor($0) ?? RealmAuthor()
                author.name = $0.name
                author.email = $0.email?.absoluteString
                return author
            }
            rarticle.authors.removeAll()
            rarticle.authors.append(objectsIn: authors)
            rarticle.published = article.published
            rarticle.updatedAt = article.updatedAt
            rarticle.content = article.content
            rarticle.read = article.read
            let flags: [RealmString] = article.flags.map { str in
                let realmString = RealmString()
                realmString.string = str
                return realmString
            }
            rarticle.flags.removeAll()
            rarticle.flags.append(objectsIn: flags)
            rarticle.relatedArticles.removeAll()
            let relatedArticles = article.relatedArticles.flatMap { self.realmArticleForArticle($0) }
            rarticle.relatedArticles.append(objectsIn: relatedArticles)
            rarticle.estimatedReadingTime = article.estimatedReadingTime

            if let feed = article.feed, let rfeed = self.realmFeedForFeed(feed) {
                rarticle.feed = rfeed
            }

            self.updateSearchIndexForArticle(article)
        }
    }

    private func synchronousDeleteFeed(_ feed: Feed) {
        if let realmFeed = self.realmFeedForFeed(feed) {
            feed.articlesArray.forEach(self.synchronousDeleteArticle)
            self.realm.delete(realmFeed)
        }
    }

    private func synchronousDeleteArticle(_ article: Article) {
        if let realmArticle = self.realmArticleForArticle(article) {
            self.realm.delete(realmArticle)
        }
    }

    private func startRealmTransaction() {
        if !self.realm.isInWriteTransaction {
            self.realm.refresh()
            self.realm.beginWrite()
        }
    }

    private func realmTransaction(_ execBlock: @escaping (Void) -> Void) -> Future<Void> {
        let promise = Promise<Void>()
        let operation = BlockOperation {
            self.startRealmTransaction()
            execBlock()
            self.startRealmTransaction()
            _ = try? self.realm.commitWrite()
            promise.resolve()
        }

        if self.workQueue == OperationQueue.current {
            operation.start()
        } else {
            self.workQueue.addOperation(operation)
        }

        return promise.future
    }
}

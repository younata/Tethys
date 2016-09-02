import RealmSwift
import Foundation
import CBGPromise
import Result

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

class RealmService: DataService {
    private let realmConfiguration: Realm.Configuration

    let mainQueue: NSOperationQueue
    let workQueue: NSOperationQueue
    let searchIndex: SearchIndex?

    init(realmConfiguration: Realm.Configuration,
        mainQueue: NSOperationQueue,
        workQueue: NSOperationQueue,
        searchIndex: SearchIndex?) {
            self.realmConfiguration = realmConfiguration
            self.mainQueue = mainQueue
            self.workQueue = workQueue
            self.searchIndex = searchIndex
    }

    private var realmsForThreads: [NSThread: Realm] = [:]
    private var realm: Realm {
        let thread = NSThread.currentThread()
        if let realm = self.realmsForThreads[thread] {
            return realm
        }

        // swiftlint:disable force_try
        let realm = try! Realm(configuration: self.realmConfiguration)
        // swiftlint:enable force_try
        self.realmsForThreads[thread] = realm

        return realm
    }

    func createFeed(callback: (Feed) -> (Void)) -> Future<Result<Feed, RNewsError>> {
        let promise = Promise<Result<Feed, RNewsError>>()
        self.realmTransaction {
            let realmFeed = self.realm.create(RealmFeed)
            let feed = Feed(realmFeed: realmFeed)

            let operation = NSBlockOperation { callback(feed) }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.synchronousUpdateFeed(feed, realmFeed: realmFeed)

            promise.resolve(.Success(feed))
        }
        return promise.future
    }

    func createArticle(feed: Feed?, callback: (Article) -> (Void)) {
        self.realmTransaction {
            let realmArticle = self.realm.create(RealmArticle)
            let article = Article(realmArticle: realmArticle, feed: feed)
            feed?.addArticle(article)

            let operation = NSBlockOperation { callback(article) }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.synchronousUpdateArticle(article, realmArticle: realmArticle)
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
        promise.resolve(.Success(feeds))
        return promise.future
    }

    func articlesMatchingPredicate(predicate: NSPredicate) ->
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
            promise.resolve(.Success(articles))
            return promise.future
    }

    // Mark: - Delete

    func deleteFeed(feed: Feed) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        let articleIdentifiers = feed.articlesArray.map { $0.identifier }
        #if os(iOS)
            self.searchIndex?.deleteIdentifierFromIndex(articleIdentifiers) {_ in }
        #endif
        self.realmTransaction {
            self.synchronousDeleteFeed(feed)
        }.then {
            self.mainQueue.addOperationWithBlock {
                promise.resolve(.Success())
            }
        }
        return promise.future
    }

    func deleteArticle(article: Article) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        #if os(iOS)
            self.searchIndex?.deleteIdentifierFromIndex([article.identifier]) {_ in }
        #endif
        self.realmTransaction {
            self.synchronousDeleteArticle(article)
        }.then {
            self.mainQueue.addOperationWithBlock {
                promise.resolve(.Success())
            }
        }
        return promise.future
    }

    // Mark: - Batch

    func batchCreate(feedCount: Int, articleCount: Int) ->
        Future<Result<([Feed], [Article]), RNewsError>> {
            let promise = Promise<Result<([Feed], [Article]), RNewsError>>()
            self.realmTransaction {
                let realmFeeds = (0..<feedCount).map { _ in self.realm.create(RealmFeed) }
                let realmArticles = (0..<articleCount).map { _ in self.realm.create(RealmArticle) }

                let feeds = realmFeeds.map(Feed.init)
                let articles = realmArticles.map { Article(realmArticle: $0, feed: nil) }

                self.mainQueue.addOperationWithBlock {
                    promise.resolve(.Success(feeds, articles))
                }
            }
            return promise.future
    }

    func batchSave(feeds: [Feed], articles: [Article]) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        self.realmTransaction {
            articles.forEach { self.synchronousUpdateArticle($0) }
            feeds.forEach { self.synchronousUpdateFeed($0) }

        }.then {
            self.mainQueue.addOperationWithBlock {
                promise.resolve(.Success())
            }
        }
        return promise.future
    }

    func deleteEverything() -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        self.realmTransaction {
            self.realm.deleteAll()

            self.mainQueue.addOperationWithBlock {
                promise.resolve(.Success())
            }
        }
        return promise.future
    }

    // Mark: - Private

    private func realmFeedForFeed(feed: Feed) -> RealmFeed? {
        guard let feedID = feed.feedID as? String else { return nil }
        return self.realm.objectForPrimaryKey(RealmFeed.self, key: feedID)
    }

    private func realmArticleForArticle(article: Article) -> RealmArticle? {
        guard let articleID = article.articleID as? String else { return nil }
        return self.realm.objectForPrimaryKey(RealmArticle.self, key: articleID)
    }

    // Synchronous update!

    private func synchronousUpdateFeed(feed: Feed, realmFeed: RealmFeed? = nil) {
        self.startRealmTransaction()

        if let rfeed = realmFeed ?? self.realmFeedForFeed(feed) {
            rfeed.title = feed.title
            rfeed.url = feed.url.absoluteString
            rfeed.summary = feed.summary
            let tags: [RealmString] = feed.tags.map { str in
                let realmString = RealmString()
                realmString.string = str
                return realmString
            }
            rfeed.tags.replaceRange(0..<rfeed.tags.count, with: tags)
            rfeed.waitPeriod = feed.waitPeriod
            rfeed.remainingWait = feed.remainingWait
            rfeed.lastUpdated = feed.lastUpdated
            #if os(iOS)
                if let image = feed.image {
                    rfeed.imageData = UIImagePNGRepresentation(image)
                }
            #else
                if let image = feed.image {
                    rfeed.imageData = image.TIFFRepresentation
                }
            #endif
        }
    }

    private func synchronousUpdateArticle(article: Article, realmArticle: RealmArticle? = nil) {
        self.startRealmTransaction()

        if let rarticle = realmArticle ?? self.realmArticleForArticle(article) {
            rarticle.title = article.title
            rarticle.link = article.link?.absoluteString ?? ""
            rarticle.summary = article.summary
            let authors: [RealmAuthor] = article.authors.map {
                let author = RealmAuthor()
                author.name = $0.name
                author.email = $0.email?.absoluteString
                return author
            }
            rarticle.authors.removeAll()
            rarticle.authors.appendContentsOf(authors)
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
            rarticle.flags.appendContentsOf(flags)
            rarticle.relatedArticles.removeAll()
            let relatedArticles = article.relatedArticles.flatMap { self.realmArticleForArticle($0) }
            rarticle.relatedArticles.appendContentsOf(relatedArticles)
            rarticle.estimatedReadingTime = article.estimatedReadingTime

            if let feed = article.feed, rfeed = self.realmFeedForFeed(feed) {
                rarticle.feed = rfeed
            }

            self.updateSearchIndexForArticle(article)
        }
    }

    private func synchronousDeleteFeed(feed: Feed) {
        if let realmFeed = self.realmFeedForFeed(feed) {
            feed.articlesArray.forEach(self.synchronousDeleteArticle)
            self.realm.delete(realmFeed)
        }
    }

    private func synchronousDeleteArticle(article: Article) {
        if let realmArticle = self.realmArticleForArticle(article) {
            self.realm.delete(realmArticle)
        }
    }

    private func startRealmTransaction() {
        if !self.realm.inWriteTransaction {
            self.realm.refresh()
            self.realm.beginWrite()
        }
    }

    private func realmTransaction(execBlock: Void -> Void) -> Future<Void> {
        let promise = Promise<Void>()
        let operation = NSBlockOperation {
            self.startRealmTransaction()
            execBlock()
            self.startRealmTransaction()
            _ = try? self.realm.commitWrite()
            promise.resolve()
        }

        if self.workQueue == NSOperationQueue.currentQueue() {
            operation.start()
        } else {
            self.workQueue.addOperation(operation)
        }

        return promise.future
    }
}

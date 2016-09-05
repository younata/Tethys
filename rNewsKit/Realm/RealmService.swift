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

    func createFeed(_ callback: (Feed) -> (Void)) -> Future<Result<Feed, RNewsError>> {
        let promise = Promise<Result<Feed, RNewsError>>()
        self.realmTransaction {
            let realmFeed = self.realm.create(RealmFeed)
            let feed = Feed(realmFeed: realmFeed)

            let operation = BlockOperation { callback(feed) }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.synchronousUpdateFeed(feed, realmFeed: realmFeed)

            promise.resolve(.Success(feed))
        }
        return promise.future
    }

    func createArticle(_ feed: Feed?, callback: @escaping (Article) -> (Void)) {
        self.realmTransaction {
            let realmArticle = self.realm.create(RealmArticle)
            let article = Article(realmArticle: realmArticle, feed: feed)
            feed?.addArticle(article)

            let operation = BlockOperation { callback(article) }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.synchronousUpdateArticle(article, realmArticle: realmArticle)
        }
    }

    // Mark: - Read

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, RNewsError>> {
        let promise = Promise<Result<DataStoreBackedArray<Feed>, RNewsError>>()
        let sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

        let feeds = DataStoreBackedArray(entityName: RealmFeed.self,
            predicate: NSPredicate(value: true),
            managedObjectContext: self.realmConfiguration,
            conversionFunction: { Feed(realmFeed: $0 as! RealmFeed) },
            sortDescriptors: sortDescriptors)
        promise.resolve(.Success(feeds))
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
            promise.resolve(.Success(articles))
            return promise.future
    }

    // Mark: - Delete

    func deleteFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>> {
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

    func deleteArticle(_ article: Article) -> Future<Result<Void, RNewsError>> {
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

    func batchCreate(_ feedCount: Int, articleCount: Int) ->
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

    func batchSave(_ feeds: [Feed], articles: [Article]) -> Future<Result<Void, RNewsError>> {
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

    private func realmFeedForFeed(_ feed: Feed) -> RealmFeed? {
        guard let feedID = feed.feedID as? String else { return nil }
        return self.realm.objectForPrimaryKey(RealmFeed.self, key: feedID)
    }

    private func realmStringForString(_ string: String) -> RealmString? {
        let predicate = NSPredicate(format: "string = %@", string)
        return self.realm.objects(RealmString).filter(predicate).first
    }

    private func realmArticleForArticle(_ article: Article) -> RealmArticle? {
        guard let articleID = article.articleID as? String else { return nil }
        return self.realm.objectForPrimaryKey(RealmArticle.self, key: articleID)
    }

    private func realmAuthorForAuthor(_ author: Author) -> RealmAuthor? {
        let predicate = NSPredicate(format: "name = %@ AND email = %@", author.name, author.email?.absoluteString ?? "")
        return self.realm.objects(RealmAuthor).filter(predicate).first
    }

    // Synchronous update!

    private func synchronousUpdateFeed(_ feed: Feed, realmFeed: RealmFeed? = nil) {
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
                    rfeed.imageData = image.TIFFRepresentation
                }
            #endif
        }
    }

    private func synchronousUpdateArticle(_ article: Article, realmArticle: RealmArticle? = nil) {
        self.startRealmTransaction()

        if let rarticle = realmArticle ?? self.realmArticleForArticle(article) {
            rarticle.title = article.title
            rarticle.link = article.link?.absoluteString ?? ""
            rarticle.summary = article.summary
            let authors: [RealmAuthor] = article.authors.map {
                let author = self.realmAuthorForAuthor($0) ?? RealmAuthor()
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
        if !self.realm.inWriteTransaction {
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

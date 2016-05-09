import RealmSwift
import Foundation
import CBGPromise

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

    func createFeed(callback: (Feed) -> (Void)) {
        self.realmTransaction {
            let realmFeed = self.realm.create(RealmFeed)
            let feed = Feed(realmFeed: realmFeed)

            let operation = NSBlockOperation { callback(feed) }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.synchronousUpdateFeed(feed, realmFeed: realmFeed)
        }
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

    func createEnclosure(article: Article?, callback: (Enclosure) -> (Void)) {
        self.realmTransaction {
            let realmEnclosure = self.realm.create(RealmEnclosure)
            let enclosure = Enclosure(realmEnclosure: realmEnclosure, article: article)
            article?.addEnclosure(enclosure)

            let operation = NSBlockOperation { callback(enclosure) }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.synchronousUpdateEnclosure(enclosure, realmEnclosure: realmEnclosure)
        }
    }

    // Mark: - Read

    func feedsMatchingPredicate(predicate: NSPredicate) -> Future<DataStoreBackedArray<Feed>> {
        let promise = Promise<DataStoreBackedArray<Feed>>()
        let sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]

        let feeds = DataStoreBackedArray(realmDataType: RealmFeed.self,
            predicate: predicate,
            realmConfiguration: self.realmConfiguration,
            conversionFunction: { Feed(realmFeed: $0 as! RealmFeed) },
            sortDescriptors: sortDescriptors)
        promise.resolve(feeds)
        return promise.future
    }

    func articlesMatchingPredicate(predicate: NSPredicate) -> Future<DataStoreBackedArray<Article>> {
        let promise = Promise<DataStoreBackedArray<Article>>()
        let sortDescriptors = [
            NSSortDescriptor(key: "updatedAt", ascending: false),
            NSSortDescriptor(key: "published", ascending: false)
        ]

        let articles = DataStoreBackedArray(realmDataType: RealmArticle.self,
            predicate: predicate,
            realmConfiguration: self.realmConfiguration,
            conversionFunction: { Article(realmArticle: $0 as! RealmArticle, feed: nil) },
            sortDescriptors: sortDescriptors)
        promise.resolve(articles)
        return promise.future
    }

    func enclosuresMatchingPredicate(predicate: NSPredicate) -> Future<DataStoreBackedArray<Enclosure>> {
        let promise = Promise<DataStoreBackedArray<Enclosure>>()
        let sortDescriptors = [NSSortDescriptor(key: "kind", ascending: true)]

        let enclosures = DataStoreBackedArray(realmDataType: RealmEnclosure.self,
            predicate: predicate,
            realmConfiguration: self.realmConfiguration,
            conversionFunction: { Enclosure(realmEnclosure: $0 as! RealmEnclosure, article: nil) },
            sortDescriptors: sortDescriptors)
        promise.resolve(enclosures)
        return promise.future
    }

    // Mark: - Update

    func saveFeed(feed: Feed) -> Future<Void> {
        let promise = Promise<Void>()
        guard let _ = feed.feedID as? String else { promise.resolve(); return promise.future }

        self.realmTransaction {
            self.synchronousUpdateFeed(feed)

            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func saveArticle(article: Article) -> Future<Void> {
        let promise = Promise<Void>()
        guard let _ = article.articleID as? String else { promise.resolve(); return promise.future }

        self.realmTransaction {
            self.synchronousUpdateArticle(article)

            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func saveEnclosure(enclosure: Enclosure) -> Future<Void> {
        let promise = Promise<Void>()
        guard let _ = enclosure.enclosureID as? String else { promise.resolve(); return promise.future}

        self.realmTransaction {
            self.synchronousUpdateEnclosure(enclosure)

            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    // Mark: - Delete

    func deleteFeed(feed: Feed) -> Future<Void> {
        let promise = Promise<Void>()
        let articleIdentifiers = feed.articlesArray.map { $0.identifier }
        #if os(iOS)
            if #available(iOS 9, *) {
                self.searchIndex?.deleteIdentifierFromIndex(articleIdentifiers) {_ in }
            }
        #endif
        self.realmTransaction {
            self.synchronousDeleteFeed(feed)
            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func deleteArticle(article: Article) -> Future<Void> {
        let promise = Promise<Void>()
        #if os(iOS)
            if #available(iOS 9, *) {
                self.searchIndex?.deleteIdentifierFromIndex([article.identifier]) {_ in }
            }
        #endif
        self.realmTransaction {
            self.synchronousDeleteArticle(article)
            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func deleteEnclosure(enclosure: Enclosure) -> Future<Void> {
        let promise = Promise<Void>()
        self.realmTransaction {
            self.synchronousDeleteEnclosure(enclosure)
            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    // Mark: - Batch

    func batchCreate(feedCount: Int, articleCount: Int, enclosureCount: Int) -> Future<([Feed], [Article], [Enclosure])> {
        let promise = Promise<([Feed], [Article], [Enclosure])>()
        self.realmTransaction {
            let realmFeeds = (0..<feedCount).map { _ in self.realm.create(RealmFeed) }
            let realmArticles = (0..<articleCount).map { _ in self.realm.create(RealmArticle) }
            let realmEnclosures = (0..<enclosureCount).map { _ in self.realm.create(RealmEnclosure) }

            let feeds = realmFeeds.map(Feed.init)
            let articles = realmArticles.map { Article(realmArticle: $0, feed: nil) }
            let enclosures = realmEnclosures.map { Enclosure(realmEnclosure: $0, article: nil) }

            self.mainQueue.addOperationWithBlock {
                promise.resolve((feeds, articles, enclosures))
            }
        }
        return promise.future
    }

    func batchSave(feeds: [Feed], articles: [Article], enclosures: [Enclosure]) -> Future<Void> {
        let promise = Promise<Void>()
        self.realmTransaction {
            enclosures.forEach { self.synchronousUpdateEnclosure($0) }
            articles.forEach { self.synchronousUpdateArticle($0) }
            feeds.forEach { self.synchronousUpdateFeed($0) }

            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func batchDelete(feeds: [Feed], articles: [Article], enclosures: [Enclosure]) -> Future<Void> {
        let promise = Promise<Void>()
        self.realmTransaction {
            enclosures.forEach(self.synchronousDeleteEnclosure)
            articles.forEach(self.synchronousDeleteArticle)
            feeds.forEach(self.synchronousDeleteFeed)

            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func deleteEverything() -> Future<Void> {
        let promise = Promise<Void>()
        self.realmTransaction {
            self.realm.deleteAll()

            self.mainQueue.addOperationWithBlock {
                promise.resolve()
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

    private func realmEnclosureForEnclosure(enclosure: Enclosure) -> RealmEnclosure? {
        guard let enclosureID = enclosure.enclosureID as? String else { return nil }
        return self.realm.objectForPrimaryKey(RealmEnclosure.self, key: enclosureID)
    }

    // Synchronous update!

    private func synchronousUpdateFeed(feed: Feed, realmFeed: RealmFeed? = nil) {
        self.startRealmTransaction()

        if let rfeed = realmFeed ?? self.realmFeedForFeed(feed) {
            rfeed.title = feed.title
            rfeed.url = feed.url?.absoluteString
            rfeed.summary = feed.summary
            rfeed.query = feed.query
            let tags: [RealmString] = feed.tags.map { str in
                let realmString = RealmString()
                realmString.string = str
                return realmString
            }
            rfeed.tags.replaceRange(0..<rfeed.tags.count, with: tags)
            rfeed.waitPeriod = feed.waitPeriod
            rfeed.remainingWait = feed.remainingWait
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

    private func synchronousUpdateEnclosure(enclosure: Enclosure, realmEnclosure: RealmEnclosure? = nil) {
        self.startRealmTransaction()

        if let renclosure = realmEnclosure ?? self.realmEnclosureForEnclosure(enclosure) {
            renclosure.url = enclosure.url.absoluteString
            renclosure.kind = enclosure.kind

            if let article = enclosure.article, rarticle = self.realmArticleForArticle(article) {
                renclosure.article = rarticle
            }
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
            article.enclosuresArray.forEach(self.synchronousDeleteEnclosure)
            self.realm.delete(realmArticle)
        }
    }

    private func synchronousDeleteEnclosure(enclosure: Enclosure) {
        if let realmEnclosure = self.realmEnclosureForEnclosure(enclosure) {
            self.realm.delete(realmEnclosure)
        }
    }

    private func startRealmTransaction() {
        if !self.realm.inWriteTransaction {
            self.realm.refresh()
            self.realm.beginWrite()
        }
    }

    private func realmTransaction(execBlock: Void -> Void) {
        let operation = NSBlockOperation {
            self.startRealmTransaction()
            execBlock()
            self.startRealmTransaction()
            _ = try? self.realm.commitWrite()
        }

        if self.workQueue == NSOperationQueue.currentQueue() {
            operation.start()
        } else {
            self.workQueue.addOperation(operation)
        }
    }
}

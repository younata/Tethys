import RealmSwift
import Foundation

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
            callback(feed)

            self.updateFeed(feed, realmFeed: realmFeed) {}
        }
    }

    func createArticle(feed: Feed?, callback: (Article) -> (Void)) {
        self.realmTransaction {
            let realmArticle = self.realm.create(RealmArticle)
            let article = Article(realmArticle: realmArticle, feed: feed)
            feed?.addArticle(article)
            callback(article)

            self.updateArticle(article, realmArticle: realmArticle) {}
        }
    }

    func createEnclosure(article: Article?, callback: (Enclosure) -> (Void)) {
        self.realmTransaction {
            let realmEnclosure = self.realm.create(RealmEnclosure)
            let enclosure = Enclosure(realmEnclosure: realmEnclosure, article: article)
            article?.addEnclosure(enclosure)
            callback(enclosure)

            self.updateEnclosure(enclosure, realmEnclosure: realmEnclosure) {}
        }
    }

    // Mark: - Read

    func feedsMatchingPredicate(predicate: NSPredicate, callback: [Feed] -> Void) {
        let sortDescriptors = [SortDescriptor(property: "title", ascending: true)]

        self.realmTransaction {
            let feeds = self.realm.objects(RealmFeed).filter(predicate)
                .sorted(sortDescriptors)
                .map { Feed(realmFeed: $0) }
            self.mainQueue.addOperationWithBlock {
                callback(feeds)
            }
        }
    }

    func articlesMatchingPredicate(predicate: NSPredicate, callback: [Article] -> Void) {
        let sortDescriptors = [
            SortDescriptor(property: "updatedAt", ascending: false),
            SortDescriptor(property: "published", ascending: false)
        ]
        self.realmTransaction {
            let articles = self.realm.objects(RealmArticle).filter(predicate)
                .sorted(sortDescriptors)
                .map { Article(realmArticle: $0, feed: nil) }
            self.mainQueue.addOperationWithBlock {
                callback(articles)
            }
        }
    }

    func enclosuresMatchingPredicate(predicate: NSPredicate, callback: [Enclosure] -> Void) {
        let sortDescriptors = [SortDescriptor(property: "kind", ascending: true)]
        self.realmTransaction {
            let enclosures = self.realm.objects(RealmEnclosure).filter(predicate)
                .sorted(sortDescriptors)
                .map { Enclosure(realmEnclosure: $0, article: nil) }

            self.mainQueue.addOperationWithBlock {
                callback(enclosures)
            }
        }
    }

    // Mark: - Update

    func saveFeed(feed: Feed, callback: (Void) -> (Void)) {
        guard let _ = feed.feedID as? String else { callback(); return }

        self.updateFeed(feed) {
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func saveArticle(article: Article, callback: (Void) -> (Void)) {
        guard let _ = article.articleID as? String else { callback(); return }

        self.updateArticle(article) {
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func saveEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        guard let _ = enclosure.enclosureID as? String else { callback(); return }

        self.updateEnclosure(enclosure) {
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    // Mark: - Delete

    func deleteFeed(feed: Feed, callback: (Void) -> (Void)) {
        let articleIdentifiers = feed.articlesArray.map { $0.identifier }
        #if os(iOS)
            if #available(iOS 9, *) {
                self.searchIndex?.deleteIdentifierFromIndex(articleIdentifiers) {_ in }
            }
        #endif
        self.realmTransaction {
            if let feed = self.realmFeedForFeed(feed) {
                for article in feed.articles {
                    for enclosure in article.enclosures {
                        self.realm.delete(enclosure)
                    }
                    self.realm.delete(article)
                }
                self.realm.delete(feed)
            }
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func deleteArticle(article: Article, callback: (Void) -> (Void)) {
        #if os(iOS)
            if #available(iOS 9, *) {
                self.searchIndex?.deleteIdentifierFromIndex([article.identifier]) {_ in }
            }
        #endif
        self.realmTransaction {
            if let article = self.realmArticleForArticle(article) {
                for enclosure in article.enclosures {
                    self.realm.delete(enclosure)
                }
                self.realm.delete(article)
            }
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func deleteEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        self.realmTransaction {
            if let enclosure = self.realmEnclosureForEnclosure(enclosure) {
                self.realm.delete(enclosure)
            }
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

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

    private func updateFeed(feed: Feed, realmFeed: RealmFeed? = nil, callback: Void -> Void) {
        self.realmTransaction {
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

            callback()
        }
    }

    private func updateArticle(article: Article, realmArticle: RealmArticle? = nil, callback: Void -> Void) {
        self.realmTransaction {
            if let rarticle = realmArticle ?? self.realmArticleForArticle(article) {
                rarticle.title = article.title
                rarticle.link = article.link?.absoluteString ?? ""
                rarticle.summary = article.summary
                rarticle.author = article.author
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
            callback()
        }
    }

    private func updateEnclosure(enclosure: Enclosure, realmEnclosure: RealmEnclosure? = nil, callback: Void -> Void) {
        self.realmTransaction {
            if let renclosure = realmEnclosure ?? self.realmEnclosureForEnclosure(enclosure) {
                renclosure.url = enclosure.url.absoluteString
                renclosure.kind = enclosure.kind

                if let article = enclosure.article, rarticle = self.realmArticleForArticle(article) {
                    renclosure.article = rarticle
                }
            }
            callback()
        }
    }

    private func realmTransaction(execBlock: Void -> Void) {
        func startRealmTransaction() {
            if !self.realm.inWriteTransaction {
                self.realm.refresh()
                self.realm.beginWrite()
            }
        }
        let operation = NSBlockOperation {
            startRealmTransaction()
            execBlock()
            startRealmTransaction()
            _ = try? self.realm.commitWrite()
        }

        if self.workQueue == NSOperationQueue.currentQueue() {
            operation.start()
        } else {
            self.workQueue.addOperation(operation)
        }
    }
}

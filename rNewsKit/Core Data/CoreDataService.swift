import Foundation
import CoreData
import CBGPromise

// swiftlint:disable file_length
class CoreDataService: DataService {
    private let managedObjectContext: NSManagedObjectContext

    let mainQueue: NSOperationQueue
    let searchIndex: SearchIndex?

    init(managedObjectContext: NSManagedObjectContext, mainQueue: NSOperationQueue, searchIndex: SearchIndex?) {
        self.managedObjectContext = managedObjectContext
        self.mainQueue = mainQueue
        self.searchIndex = searchIndex
    }

    deinit {
        self.managedObjectContext.reset()
    }

    // Mark: - Create

    func createFeed(callback: (Feed) -> (Void)) {
        let entityDescription = NSEntityDescription.entityForName("Feed",
            inManagedObjectContext: self.managedObjectContext)!
        self.managedObjectContext.performBlock {
            let cdfeed = CoreDataFeed(entity: entityDescription,
                insertIntoManagedObjectContext: self.managedObjectContext)
            let _ = try? self.managedObjectContext.save()
            let feed = Feed(coreDataFeed: cdfeed)
            let operation = NSBlockOperation {
                callback(feed)
            }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.updateFeed(feed)
        }
    }

    func createArticle(feed: Feed?, callback: (Article) -> (Void)) {
        let entityDescription = NSEntityDescription.entityForName("Article",
            inManagedObjectContext: self.managedObjectContext)!
        self.managedObjectContext.performBlock {
            let cdarticle = CoreDataArticle(entity: entityDescription,
                insertIntoManagedObjectContext: self.managedObjectContext)
            let _ = try? self.managedObjectContext.save()
            let article = Article(coreDataArticle: cdarticle, feed: feed)
            feed?.addArticle(article)
            let operation = NSBlockOperation {
                callback(article)
            }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.updateArticle(article)
        }
    }

    func createEnclosure(article: Article?, callback: (Enclosure) -> (Void)) {
        let entityDescription = NSEntityDescription.entityForName("Enclosure",
            inManagedObjectContext: self.managedObjectContext)!
        self.managedObjectContext.performBlock {
            let cdenclosure = CoreDataEnclosure(entity: entityDescription,
                insertIntoManagedObjectContext: self.managedObjectContext)
            let _ = try? self.managedObjectContext.save()
            let enclosure = Enclosure(coreDataEnclosure: cdenclosure, article: article)
            article?.addEnclosure(enclosure)
            enclosure.article = article
            let operation = NSBlockOperation {
                callback(enclosure)
            }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.updateEnclosure(enclosure)
        }
    }

    // Mark: - Read

    func feedsMatchingPredicate(predicate: NSPredicate) -> Future<DataStoreBackedArray<Feed>> {
        let promise = Promise<DataStoreBackedArray<Feed>>()
        let sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        let feeds = DataStoreBackedArray(entityName: "Feed",
            predicate: predicate,
            managedObjectContext: self.managedObjectContext,
            conversionFunction: { Feed(coreDataFeed: $0 as! CoreDataFeed) },
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
        let articles = DataStoreBackedArray(entityName: "Article",
            predicate: predicate,
            managedObjectContext: self.managedObjectContext,
            conversionFunction: { Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil) },
            sortDescriptors: sortDescriptors)
        promise.resolve(articles)
        return promise.future
    }

    func enclosuresMatchingPredicate(predicate: NSPredicate) -> Future<DataStoreBackedArray<Enclosure>> {
        let promise = Promise<DataStoreBackedArray<Enclosure>>()
        let sortDescriptors = [NSSortDescriptor(key: "kind", ascending: true)]
        let enclosures = DataStoreBackedArray(entityName: "Enclosure",
            predicate: predicate,
            managedObjectContext: self.managedObjectContext,
            conversionFunction: { Enclosure(coreDataEnclosure: $0 as! CoreDataEnclosure, article: nil) },
            sortDescriptors: sortDescriptors)
        promise.resolve(enclosures)
        return promise.future
    }

    // Mark: - Update

    func saveFeed(feed: Feed) -> Future<Void>{
        let promise = Promise<Void>()
        guard let _ = feed.feedID as? NSManagedObjectID else { promise.resolve(); return promise.future }

        self.managedObjectContext.performBlock {
            self.updateFeed(feed)
            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func saveArticle(article: Article) -> Future<Void> {
        let promise = Promise<Void>()
        guard let _ = article.articleID as? NSManagedObjectID else { promise.resolve(); return promise.future }

        self.managedObjectContext.performBlock {
            self.updateArticle(article)
            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func saveEnclosure(enclosure: Enclosure) -> Future<Void> {
        let promise = Promise<Void>()
        guard let _ = enclosure.enclosureID as? NSManagedObjectID else { promise.resolve(); return promise.future }

        self.managedObjectContext.performBlock {
            self.updateEnclosure(enclosure)
            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    // Mark: - Delete

    func deleteFeed(feed: Feed) -> Future<Void> {
        let promise = Promise<Void>()
        guard let _ = feed.feedID as? NSManagedObjectID else { promise.resolve(); return promise.future }
        self.managedObjectContext.performBlock {
            self.deleteFeed(feed, deleteArticles: true)
            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func deleteArticle(article: Article) -> Future<Void> {
        let promise = Promise<Void>()
        guard let _ = article.articleID as? NSManagedObjectID else { promise.resolve(); return promise.future }
        self.managedObjectContext.performBlock {
            self.deleteArticle(article, deleteEnclosures: true)
            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func deleteEnclosure(enclosure: Enclosure) -> Future<Void> {
        let promise = Promise<Void>()
        guard let _ = enclosure.enclosureID as? NSManagedObjectID else { promise.resolve(); return promise.future }
        self.managedObjectContext.performBlock {
            self.privateDeleteEnclosure(enclosure)
            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    // Mark: - Batch

    func batchCreate(feedCount: Int, articleCount: Int, enclosureCount: Int) -> Future<([Feed], [Article], [Enclosure])> {
        let promise = Promise<([Feed], [Article], [Enclosure])>()
        let feedEntityDescription = NSEntityDescription.entityForName("Feed",
            inManagedObjectContext: self.managedObjectContext)!
        let articleEntityDescription = NSEntityDescription.entityForName("Article",
            inManagedObjectContext: self.managedObjectContext)!
        let enclosureEntityDescription = NSEntityDescription.entityForName("Enclosure",
            inManagedObjectContext: self.managedObjectContext)!

        self.managedObjectContext.performBlock {
            autoreleasepool {
                let cdfeeds = (0..<feedCount).map { _ in
                    return CoreDataFeed(entity: feedEntityDescription,
                        insertIntoManagedObjectContext: self.managedObjectContext)
                }
                let cdarticles = (0..<articleCount).map { _ in
                    return CoreDataArticle(entity: articleEntityDescription,
                        insertIntoManagedObjectContext: self.managedObjectContext)
                }
                let cdenclosures = (0..<enclosureCount).map { _ in
                    return CoreDataEnclosure(entity: enclosureEntityDescription,
                        insertIntoManagedObjectContext: self.managedObjectContext)
                }
                let _ = try? self.managedObjectContext.save()

                let feeds = cdfeeds.map(Feed.init)
                let articles = cdarticles.map { Article(coreDataArticle: $0, feed: nil) }
                let enclosures = cdenclosures.map { Enclosure(coreDataEnclosure: $0, article: nil) }

                self.mainQueue.addOperationWithBlock {
                    promise.resolve((feeds, articles, enclosures))
                }
            }
        }
        return promise.future
    }

    func batchSave(feeds: [Feed], articles: [Article], enclosures: [Enclosure]) -> Future<Void> {
        let promise = Promise<Void>()
        self.managedObjectContext.performBlock {
            autoreleasepool {
                feeds.forEach(self.updateFeed)
                articles.forEach(self.updateArticle)
                enclosures.forEach(self.updateEnclosure)
            }

            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func batchDelete(feeds: [Feed], articles: [Article], enclosures: [Enclosure]) -> Future<Void> {
        let promise = Promise<Void>()
        self.managedObjectContext.performBlock {
            autoreleasepool {
                #if os(iOS)
                    if #available(iOS 9, *) {
                        let articleIdentifiers = articles.map { $0.identifier }

                        self.searchIndex?.deleteIdentifierFromIndex(articleIdentifiers) {_ in }
                    }
                #endif

                self.coreDataEnclosuresForEnclosures(enclosures).forEach(self.managedObjectContext.deleteObject)
                self.coreDataArticlesForArticles(articles).forEach(self.managedObjectContext.deleteObject)
                self.coreDataFeedsForFeeds(feeds).forEach(self.managedObjectContext.deleteObject)

                _ = try? self.managedObjectContext.save()
            }

            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    func deleteEverything() -> Future<Void> {
        let promise = Promise<Void>()
        self.managedObjectContext.performBlock {
            self.managedObjectContext.reset()
            let deleteAllEntitiesOfType: String -> Void = { entityType in
                autoreleasepool {
                    let request = NSFetchRequest()
                    request.entity = NSEntityDescription.entityForName(entityType,
                        inManagedObjectContext: self.managedObjectContext)

                    if #available(iOS 9, *) {
                        let store = self.managedObjectContext.persistentStoreCoordinator!
                        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                        _ = try? store.executeRequest(deleteRequest, withContext: self.managedObjectContext)
                    } else {
                        request.resultType = .ManagedObjectIDResultType
                        request.includesPropertyValues = false
                        request.includesSubentities = false
                        request.returnsObjectsAsFaults = true
                        let objects = (try? self.managedObjectContext.executeFetchRequest(request) ?? [])
                            as? [NSManagedObject]

                        objects?.forEach(self.managedObjectContext.deleteObject)
                        _ = try? self.managedObjectContext.save()
                    }
                }
            }

            deleteAllEntitiesOfType("Feed")
            deleteAllEntitiesOfType("Article")
            deleteAllEntitiesOfType("Enclosure")

            self.mainQueue.addOperationWithBlock {
                promise.resolve()
            }
        }
        return promise.future
    }

    // Mark: - Private

    // Danger will robinson, this is meant to be inside a managedObjectContext's performBlock block!
    private func coreDataFeedForFeed(feed: Feed) -> CoreDataFeed? {
        return self.coreDataFeedsForFeeds([feed]).first
    }

    private func coreDataArticleForArticle(article: Article) -> CoreDataArticle? {
        return self.coreDataArticlesForArticles([article]).first
    }

    private func coreDataEnclosureForEnclosure(enclosure: Enclosure) -> CoreDataEnclosure? {
        return self.coreDataEnclosuresForEnclosures([enclosure]).first
    }

    private func coreDataFeedsForFeeds(feeds: [Feed]) -> [CoreDataFeed] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Feed",
            inManagedObjectContext: managedObjectContext)
        let ids = feeds.flatMap { $0.feedID as? NSManagedObjectID }
        request.predicate = NSPredicate(format: "self IN %@", ids)
        return (try? self.managedObjectContext.executeFetchRequest(request) ?? []) as? [CoreDataFeed] ?? []
    }

    private func coreDataArticlesForArticles(articles: [Article]) -> [CoreDataArticle] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Article",
            inManagedObjectContext: managedObjectContext)
        let ids = articles.flatMap { $0.articleID as? NSManagedObjectID }
        request.predicate = NSPredicate(format: "self IN %@", ids)
        return (try? self.managedObjectContext.executeFetchRequest(request) ?? []) as? [CoreDataArticle] ?? []
    }

    private func coreDataEnclosuresForEnclosures(enclosures: [Enclosure]) -> [CoreDataEnclosure] {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Enclosure",
            inManagedObjectContext: managedObjectContext)
        let ids = enclosures.flatMap { $0.enclosureID as? NSManagedObjectID }
        request.predicate = NSPredicate(format: "self IN %@", ids)
        return (try? self.managedObjectContext.executeFetchRequest(request) ?? []) as? [CoreDataEnclosure] ?? []
    }

    // synchronous update!

    private func updateFeed(feed: Feed) {
        if let cdfeed = self.coreDataFeedForFeed(feed) {
            cdfeed.title = feed.title
            cdfeed.url = feed.url?.absoluteString
            cdfeed.summary = feed.summary
            cdfeed.query = feed.query
            cdfeed.tags = feed.tags
            cdfeed.waitPeriodInt = feed.waitPeriod
            cdfeed.remainingWaitInt = feed.remainingWait
            cdfeed.image = feed.image

            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refreshObject(cdfeed, mergeChanges: false)
        }
    }

    private func updateArticle(article: Article) {
        if let cdarticle = self.coreDataArticleForArticle(article) {
            cdarticle.title = article.title
            cdarticle.link = article.link?.absoluteString
            cdarticle.summary = article.summary
            cdarticle.author = article.authors.first?.description ?? ""
            cdarticle.published = article.published
            cdarticle.updatedAt = article.updatedAt
            cdarticle.content = article.content
            cdarticle.read = article.read
            cdarticle.flags = article.flags
            cdarticle.estimatedReadingTime = NSNumber(integer: article.estimatedReadingTime)

            if let feed = article.feed, cdfeed = self.coreDataFeedForFeed(feed) {
                cdarticle.feed = cdfeed
            }

            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refreshObject(cdarticle, mergeChanges: false)

            self.updateSearchIndexForArticle(article)
        }
    }

    private func updateEnclosure(enclosure: Enclosure) {
        if let cdenclosure = self.coreDataEnclosureForEnclosure(enclosure) {
            cdenclosure.url = enclosure.url.absoluteString
            cdenclosure.kind = enclosure.kind

            if let article = enclosure.article, cdarticle = self.coreDataArticleForArticle(article) {
                cdenclosure.article = cdarticle
            }

            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refreshObject(cdenclosure, mergeChanges: false)
        }
    }

    private func deleteFeed(feed: Feed, deleteArticles: Bool) {
        if let cdfeed = self.coreDataFeedForFeed(feed) {
            if deleteArticles {
                #if os(iOS)
                    if #available(iOS 9, *) {
                        let articleIdentifiers = feed.articlesArray.map { $0.identifier }

                        self.searchIndex?.deleteIdentifierFromIndex(articleIdentifiers) {_ in }
                    }
                #endif

                for article in cdfeed.articles {
                    for enclosure in article.enclosures {
                        self.managedObjectContext.deleteObject(enclosure)
                        self.managedObjectContext.refreshObject(enclosure, mergeChanges: false)
                    }
                    self.managedObjectContext.deleteObject(article)
                    self.managedObjectContext.refreshObject(article, mergeChanges: false)
                }
            }
            self.managedObjectContext.deleteObject(cdfeed)
            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refreshObject(cdfeed, mergeChanges: false)
        }
    }

    private func deleteArticle(article: Article, deleteEnclosures: Bool) {
        if let cdarticle = self.coreDataArticleForArticle(article) {
            if deleteEnclosures {
                for enclosure in cdarticle.enclosures {
                    self.managedObjectContext.deleteObject(enclosure)
                }
            }
            self.managedObjectContext.deleteObject(cdarticle)
            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refreshObject(cdarticle, mergeChanges: false)

            #if os(iOS)
                if #available(iOS 9, *) {
                    self.searchIndex?.deleteIdentifierFromIndex([article.identifier]) {_ in }
                }
            #endif
        }
    }

    private func privateDeleteEnclosure(enclosure: Enclosure) {
        if let cdenclosure = self.coreDataEnclosureForEnclosure(enclosure) {
            self.managedObjectContext.deleteObject(cdenclosure)
            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refreshObject(cdenclosure, mergeChanges: false)
        }
    }
}
// swiftlint:enable file_length

import Foundation
import CoreData

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

    func feedsMatchingPredicate(predicate: NSPredicate, callback: DataStoreBackedArray<Feed> -> Void) {
        let sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        let feeds = DataStoreBackedArray(entityName: "Feed",
            predicate: predicate,
            managedObjectContext: self.managedObjectContext,
            conversionFunction: { Feed(coreDataFeed: $0 as! CoreDataFeed) },
            sortDescriptors: sortDescriptors)
        callback(feeds)
    }

    func articlesMatchingPredicate(predicate: NSPredicate, callback: DataStoreBackedArray<Article> -> Void) {
        let sortDescriptors = [
            NSSortDescriptor(key: "updatedAt", ascending: false),
            NSSortDescriptor(key: "published", ascending: false)
        ]
        let articles = DataStoreBackedArray(entityName: "Article",
            predicate: predicate,
            managedObjectContext: self.managedObjectContext,
            conversionFunction: { Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil) },
            sortDescriptors: sortDescriptors)
        callback(articles)
    }

    func enclosuresMatchingPredicate(predicate: NSPredicate, callback: DataStoreBackedArray<Enclosure> -> Void) {
        let sortDescriptors = [NSSortDescriptor(key: "kind", ascending: true)]
        let enclosures = DataStoreBackedArray(entityName: "Enclosure",
            predicate: predicate,
            managedObjectContext: self.managedObjectContext,
            conversionFunction: { Enclosure(coreDataEnclosure: $0 as! CoreDataEnclosure, article: nil) },
            sortDescriptors: sortDescriptors)
        callback(enclosures)
    }

    // Mark: - Update

    func saveFeed(feed: Feed, callback: (Void) -> (Void)) {
        guard let _ = feed.feedID as? NSManagedObjectID else { callback(); return }

        self.managedObjectContext.performBlock {
            self.updateFeed(feed)
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func saveArticle(article: Article, callback: (Void) -> (Void)) {
        guard let _ = article.articleID as? NSManagedObjectID else { callback(); return }

        self.managedObjectContext.performBlock {
            self.updateArticle(article)
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func saveEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        guard let _ = enclosure.enclosureID as? NSManagedObjectID else { callback(); return }

        self.managedObjectContext.performBlock {
            self.updateEnclosure(enclosure)
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    // Mark: - Delete

    func deleteFeed(feed: Feed, callback: (Void) -> (Void)) {
        guard let _ = feed.feedID as? NSManagedObjectID else { callback(); return }
        self.managedObjectContext.performBlock {
            self.deleteFeed(feed)
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func deleteArticle(article: Article, callback: (Void) -> (Void)) {
        guard let _ = article.articleID as? NSManagedObjectID else { callback(); return }
        self.managedObjectContext.performBlock {
            self.deleteArticle(article)
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func deleteEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        guard let _ = enclosure.enclosureID as? NSManagedObjectID else { callback(); return }
        self.managedObjectContext.performBlock {
            self.deleteEnclosure(enclosure)
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    // Mark: - Batch

    func batchCreate(feedCount: Int, articleCount: Int, enclosureCount: Int, callback: BatchCreateCallback) {
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
                    callback(feeds, articles, enclosures)
                }
            }
        }
    }

    func batchSave(feeds: [Feed], articles: [Article], enclosures: [Enclosure], callback: Void -> Void) {
        self.managedObjectContext.performBlock {
            autoreleasepool {
                feeds.forEach(self.updateFeed)
                articles.forEach(self.updateArticle)
                enclosures.forEach(self.updateEnclosure)
            }

            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func batchDelete(feeds: [Feed], articles: [Article], enclosures: [Enclosure], callback: Void -> Void) {
        self.managedObjectContext.performBlock {
            autoreleasepool {
                enclosures.forEach(self.deleteEnclosure)
                articles.forEach(self.deleteArticle)
                feeds.forEach(self.deleteFeed)
            }

            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    // Mark: - Private

    // Danger will robinson, this is meant to be inside a managedObjectContext's performBlock block!
    private func coreDataFeedForFeed(feed: Feed) -> CoreDataFeed? {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Feed",
            inManagedObjectContext: managedObjectContext)
        request.predicate = NSPredicate(format: "self == %@", feed.feedID! as! NSManagedObjectID)
        let objects = (try? self.managedObjectContext.executeFetchRequest(request) ?? []) as? [NSManagedObject] ?? []

        return (objects as? [CoreDataFeed])?.first
    }

    // Danger will robinson, this is meant to be inside a managedObjectContext's performBlock block!
    private func coreDataArticleForArticle(article: Article) -> CoreDataArticle? {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Article",
            inManagedObjectContext: managedObjectContext)
        request.predicate = NSPredicate(format: "self == %@", article.articleID! as! NSManagedObjectID)
        let objects = (try? self.managedObjectContext.executeFetchRequest(request) ?? []) as? [NSManagedObject] ?? []

        return (objects as? [CoreDataArticle])?.first
    }

    // Danger will robinson, this is meant to be inside a managedObjectContext's performBlock block!
    private func coreDataEnclosureForEnclosure(enclosure: Enclosure) -> CoreDataEnclosure? {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Enclosure",
            inManagedObjectContext: managedObjectContext)
        request.predicate = NSPredicate(format: "self == %@", enclosure.enclosureID! as! NSManagedObjectID)
        let objects = (try? self.managedObjectContext.executeFetchRequest(request) ?? []) as? [NSManagedObject] ?? []

        return (objects as? [CoreDataEnclosure])?.first
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

            self.managedObjectContext.refreshObject(cdfeed, mergeChanges: true)
        }
    }

    private func updateArticle(article: Article) {
        if let cdarticle = self.coreDataArticleForArticle(article) {
            cdarticle.title = article.title
            cdarticle.link = article.link?.absoluteString
            cdarticle.summary = article.summary
            cdarticle.author = article.author
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

            self.managedObjectContext.refreshObject(cdarticle, mergeChanges: true)

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

            self.managedObjectContext.refreshObject(cdenclosure, mergeChanges: true)
        }
    }

    private func deleteFeed(feed: Feed) {
        if let cdfeed = self.coreDataFeedForFeed(feed) {
            for article in cdfeed.articles {
                for enclosure in article.enclosures {
                    self.managedObjectContext.deleteObject(enclosure)
                    self.managedObjectContext.refreshObject(enclosure, mergeChanges: false)
                }
                self.managedObjectContext.deleteObject(article)
                self.managedObjectContext.refreshObject(article, mergeChanges: false)
            }
            self.managedObjectContext.deleteObject(cdfeed)
            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refreshObject(cdfeed, mergeChanges: false)
        }

        #if os(iOS)
            if #available(iOS 9, *) {
                let articleIdentifiers = feed.articlesArray.map { $0.identifier }

                self.searchIndex?.deleteIdentifierFromIndex(articleIdentifiers) {_ in }
            }
        #endif
    }

    private func deleteArticle(article: Article) {
        if let cdarticle = self.coreDataArticleForArticle(article) {
            for enclosure in cdarticle.enclosures {
                self.managedObjectContext.deleteObject(enclosure)
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

    private func deleteEnclosure(enclosure: Enclosure) {
        if let cdenclosure = self.coreDataEnclosureForEnclosure(enclosure) {
            self.managedObjectContext.deleteObject(cdenclosure)
            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refreshObject(cdenclosure, mergeChanges: false)
        }
    }
}

import Foundation
import CoreData
import CBGPromise
import Result

class CoreDataService: DataService {
    private let managedObjectContext: NSManagedObjectContext

    let mainQueue: OperationQueue
    let searchIndex: SearchIndex?

    init(managedObjectContext: NSManagedObjectContext, mainQueue: OperationQueue, searchIndex: SearchIndex?) {
        self.managedObjectContext = managedObjectContext
        self.mainQueue = mainQueue
        self.searchIndex = searchIndex
    }

    deinit {
        self.managedObjectContext.reset()
    }

    // Mark: - Create

    func createFeed(_ callback: @escaping (Feed) -> (Void)) -> Future<Result<Feed, RNewsError>> {
        let entityDescription = NSEntityDescription.entity(forEntityName: "Feed",
            in: self.managedObjectContext)!
        let promise = Promise<Result<Feed, RNewsError>>()
        self.managedObjectContext.perform {
            let cdfeed = CoreDataFeed(entity: entityDescription,
                insertInto: self.managedObjectContext)
            cdfeed.url = ""
            let _ = try? self.managedObjectContext.save()
            let feed = Feed(coreDataFeed: cdfeed)
            let operation = BlockOperation {
                callback(feed)
            }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.updateFeed(feed)
            promise.resolve(.success(feed))
        }
        return promise.future
    }

    func createArticle(_ feed: Feed?, callback: @escaping (Article) -> (Void)) {
        let entityDescription = NSEntityDescription.entity(forEntityName: "Article",
            in: self.managedObjectContext)!
        self.managedObjectContext.perform {
            let cdarticle = CoreDataArticle(entity: entityDescription,
                insertInto: self.managedObjectContext)
            let _ = try? self.managedObjectContext.save()
            let article = Article(coreDataArticle: cdarticle, feed: feed)
            feed?.addArticle(article)
            let operation = BlockOperation {
                callback(article)
            }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.updateArticle(article)
        }
    }

    // Mark: - Read

    func allFeeds() -> Future<Result<DataStoreBackedArray<Feed>, RNewsError>> {
        let promise = Promise<Result<DataStoreBackedArray<Feed>, RNewsError>>()
        let sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        let feeds = DataStoreBackedArray(entityName: "Feed",
            predicate: NSPredicate(value: true),
            managedObjectContext: self.managedObjectContext,
            conversionFunction: { Feed(coreDataFeed: $0 as! CoreDataFeed) },
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
            let articles = DataStoreBackedArray(entityName: "Article",
                predicate: predicate,
                managedObjectContext: self.managedObjectContext,
                conversionFunction: { Article(coreDataArticle: $0 as! CoreDataArticle, feed: nil) },
                sortDescriptors: sortDescriptors)
            promise.resolve(.success(articles))
            return promise.future
    }

    // Mark: - Delete

    func deleteFeed(_ feed: Feed) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        guard let _ = feed.feedID as? NSManagedObjectID else {
            promise.resolve(.failure(.database(.unknown)))
            return promise.future
        }
        self.managedObjectContext.perform {
            self.deleteFeed(feed, deleteArticles: true)
            self.mainQueue.addOperation {
                promise.resolve(.success())
            }
        }
        return promise.future
    }

    func deleteArticle(_ article: Article) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        guard let _ = article.articleID as? NSManagedObjectID else {
            promise.resolve(.failure(.database(.unknown)))
            return promise.future
        }
        self.managedObjectContext.perform {
            self.privateDeleteArticle(article)
            self.mainQueue.addOperation {
                promise.resolve(.success())
            }
        }
        return promise.future
    }

    // Mark: - Batch

    func batchCreate(_ feedCount: Int, articleCount: Int) ->
        Future<Result<([Feed], [Article]), RNewsError>> {
            let promise = Promise<Result<([Feed], [Article]), RNewsError>>()
            let feedEntityDescription = NSEntityDescription.entity(forEntityName: "Feed",
                in: self.managedObjectContext)!
            let articleEntityDescription = NSEntityDescription.entity(forEntityName: "Article",
                in: self.managedObjectContext)!
            self.managedObjectContext.perform {
                autoreleasepool {
                    let cdfeeds = (0..<feedCount).map { _ in
                        return CoreDataFeed(entity: feedEntityDescription,
                            insertInto: self.managedObjectContext)
                    }
                    let cdarticles = (0..<articleCount).map { _ in
                        return CoreDataArticle(entity: articleEntityDescription,
                            insertInto: self.managedObjectContext)
                    }
                    let _ = try? self.managedObjectContext.save()

                    let feeds = cdfeeds.map(Feed.init)
                    let articles = cdarticles.map { Article(coreDataArticle: $0, feed: nil) }

                    self.mainQueue.addOperation {
                        promise.resolve(.success(feeds, articles))
                    }
                }
            }
            return promise.future
    }

    func batchSave(_ feeds: [Feed], articles: [Article]) -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        self.managedObjectContext.perform {
            autoreleasepool {
                feeds.forEach(self.updateFeed)
                articles.forEach(self.updateArticle)
            }

            self.mainQueue.addOperation {
                promise.resolve(.success())
            }
        }
        return promise.future
    }

    func deleteEverything() -> Future<Result<Void, RNewsError>> {
        let promise = Promise<Result<Void, RNewsError>>()
        self.managedObjectContext.perform {
            self.managedObjectContext.reset()
            let deleteAllEntitiesOfType: (String) -> Void = { entityType in
                autoreleasepool {
                    let request = NSFetchRequest<NSManagedObject>()
                    request.entity = NSEntityDescription.entity(forEntityName: entityType,
                        in: self.managedObjectContext)
                    request.resultType = .managedObjectIDResultType
                    request.includesPropertyValues = false
                    request.includesSubentities = false
                    request.returnsObjectsAsFaults = true
                    let objects = (try? self.managedObjectContext.fetch(request) )

                    objects?.forEach(self.managedObjectContext.delete(_:))
                    _ = try? self.managedObjectContext.save()
                }
            }

            deleteAllEntitiesOfType("Feed")
            deleteAllEntitiesOfType("Article")

            self.mainQueue.addOperation {
                promise.resolve(.success())
            }
        }
        return promise.future
    }

    // Mark: - Private

    // Danger will robinson, this is meant to be inside a managedObjectContext's performBlock block!
    private func coreDataFeedForFeed(_ feed: Feed) -> CoreDataFeed? {
        return self.coreDataFeedsForFeeds([feed]).first
    }

    private func coreDataArticleForArticle(_ article: Article) -> CoreDataArticle? {
        return self.coreDataArticlesForArticles([article]).first
    }

    private func coreDataFeedsForFeeds(_ feeds: [Feed]) -> [CoreDataFeed] {
        let request = NSFetchRequest<NSManagedObject>()
        request.entity = NSEntityDescription.entity(forEntityName: "Feed",
            in: managedObjectContext)
        let ids = feeds.flatMap { $0.feedID as? NSManagedObjectID }
        request.predicate = NSPredicate(format: "self IN %@", ids)
        return (try? self.managedObjectContext.fetch(request) ) as? [CoreDataFeed] ?? []
    }

    private func coreDataArticlesForArticles(_ articles: [Article]) -> [CoreDataArticle] {
        let request = NSFetchRequest<NSManagedObject>()
        request.entity = NSEntityDescription.entity(forEntityName: "Article",
            in: managedObjectContext)
        let ids = articles.flatMap { $0.articleID as? NSManagedObjectID }
        request.predicate = NSPredicate(format: "self IN %@", ids)
        return (try? self.managedObjectContext.fetch(request) ) as? [CoreDataArticle] ?? []
    }

    // synchronous update!

    private func updateFeed(_ feed: Feed) {
        if let cdfeed = self.coreDataFeedForFeed(feed) {
            cdfeed.title = feed.title
            cdfeed.url = feed.url.absoluteString
            cdfeed.summary = feed.summary
            cdfeed.tags = feed.tags
            cdfeed.waitPeriodInt = feed.waitPeriod
            cdfeed.remainingWaitInt = feed.remainingWait
            cdfeed.image = feed.image

            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refresh(cdfeed, mergeChanges: false)
        }
    }

    private func updateArticle(_ article: Article) {
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
            cdarticle.estimatedReadingTime = NSNumber(value: article.estimatedReadingTime)

            if let feed = article.feed, let cdfeed = self.coreDataFeedForFeed(feed) {
                cdarticle.feed = cdfeed
            }

            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refresh(cdarticle, mergeChanges: false)

            self.updateSearchIndexForArticle(article)
        }
    }

    private func deleteFeed(_ feed: Feed, deleteArticles: Bool) {
        if let cdfeed = self.coreDataFeedForFeed(feed) {
            if deleteArticles {
                #if os(iOS)
                    let articleIdentifiers = feed.articlesArray.map { $0.identifier }

                    self.searchIndex?.deleteIdentifierFromIndex(articleIdentifiers) {_ in }
                #endif

                for article in cdfeed.articles {
                    self.managedObjectContext.delete(article)
                    self.managedObjectContext.refresh(article, mergeChanges: false)
                }
            }
            self.managedObjectContext.delete(cdfeed)
            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refresh(cdfeed, mergeChanges: false)
        }
    }

    private func privateDeleteArticle(_ article: Article) {
        if let cdarticle = self.coreDataArticleForArticle(article) {
            self.managedObjectContext.delete(cdarticle)
            let _ = try? self.managedObjectContext.save()

            self.managedObjectContext.refresh(cdarticle, mergeChanges: false)

            #if os(iOS)
                self.searchIndex?.deleteIdentifierFromIndex([article.identifier]) {_ in }
            #endif
        }
    }
}

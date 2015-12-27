import Foundation
import CoreData

class CoreDataService: DataService {
    private let managedObjectContext: NSManagedObjectContext
    private let mainQueue: NSOperationQueue

    init(managedObjectContext: NSManagedObjectContext, mainQueue: NSOperationQueue) {
        self.managedObjectContext = managedObjectContext
        self.mainQueue = mainQueue
    }

    // Mark: - Create

    func createFeed(callback: (Feed) -> (Void)) {
        let entityDescription = NSEntityDescription.entityForName("Feed",
            inManagedObjectContext: self.managedObjectContext)!
        self.managedObjectContext.performBlock {
            let cdfeed = CoreDataFeed(entity: entityDescription,
                insertIntoManagedObjectContext: self.managedObjectContext)
            let _ = try? self.managedObjectContext.save()
            let feed = Feed(feed: cdfeed)
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
            let article = Article(article: cdarticle, feed: feed)
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
            let enclosure = Enclosure(enclosure: cdenclosure, article: article)
            let operation = NSBlockOperation {
                callback(enclosure)
            }
            self.mainQueue.addOperations([operation], waitUntilFinished: true)

            self.updateEnclosure(enclosure)
        }
    }

    // Mark: - Read

    func feedsMatchingPredicate(predicate: NSPredicate, callback: [Feed] -> Void) {
        let sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        self.entities("Feed", predicate: predicate, sortDescriptors: sortDescriptors) { objects in
            let objects = objects as? [CoreDataFeed] ?? []
            let feeds = objects.map { Feed(feed: $0) }
            self.mainQueue.addOperationWithBlock {
                callback(feeds)
            }
        }
    }

    func articlesMatchingPredicate(predicate: NSPredicate, callback: [Article] -> Void) {
        let sortDescriptors = [
            NSSortDescriptor(key: "updatedAt", ascending: false),
            NSSortDescriptor(key: "published", ascending: false)
        ]
        self.entities("Article", predicate: predicate, sortDescriptors: sortDescriptors) { objects in
            let array = objects as? [CoreDataArticle] ?? []
            let articles = array.map {
                return Article(article: $0, feed: nil)
            }
            self.mainQueue.addOperationWithBlock {
                callback(articles)
            }
        }
    }

    func enclosuresMatchingPredicate(predicate: NSPredicate, callback: [Enclosure] -> Void) {
        let sortDescriptors = [NSSortDescriptor(key: "kind", ascending: true)]
        self.entities("Enclosure", predicate: predicate, sortDescriptors: sortDescriptors) { objects in
            let array = objects as? [CoreDataEnclosure] ?? []
            let enclosures = array.map {
                return Enclosure(enclosure: $0, article: nil)
            }
            self.mainQueue.addOperationWithBlock {
                callback(enclosures)
            }
        }
    }

    // Mark: - Update

    func saveFeed(feed: Feed, callback: (Void) -> (Void)) {
        guard let _ = feed.feedID else { callback(); return }

        self.managedObjectContext.performBlock {
            self.updateFeed(feed)
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func saveArticle(article: Article, callback: (Void) -> (Void)) {
        guard let _ = article.articleID else { callback(); return }

        self.managedObjectContext.performBlock {
            self.updateArticle(article)
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func saveEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        guard let _ = enclosure.enclosureID else { callback(); return }

        self.managedObjectContext.performBlock {
            self.updateEnclosure(enclosure)
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    // Mark: - Delete

    func deleteFeed(feed: Feed, callback: (Void) -> (Void)) {
        self.managedObjectContext.performBlock {
            if let cdfeed = self.coreDataFeedForFeed(feed) {
                for article in cdfeed.articles {
                    for enclosure in article.enclosures {
                        self.managedObjectContext.deleteObject(enclosure)
                    }
                    self.managedObjectContext.deleteObject(article)
                }
                self.managedObjectContext.deleteObject(cdfeed)
                let _ = try? self.managedObjectContext.save()
            }
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func deleteArticle(article: Article, callback: (Void) -> (Void)) {
        self.managedObjectContext.performBlock {
            if let cdarticle = self.coreDataArticleForArticle(article) {
                for enclosure in cdarticle.enclosures {
                    self.managedObjectContext.deleteObject(enclosure)
                }
                self.managedObjectContext.deleteObject(cdarticle)
                let _ = try? self.managedObjectContext.save()
            }
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    func deleteEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        self.managedObjectContext.performBlock {
            if let cdenclosure = self.coreDataEnclosureForEnclosure(enclosure) {
                self.managedObjectContext.deleteObject(cdenclosure)
                let _ = try? self.managedObjectContext.save()
            }
            self.mainQueue.addOperationWithBlock(callback)
        }
    }

    // Mark: - Private

    private func entities(entity: String,
        predicate: NSPredicate,
        sortDescriptors: [NSSortDescriptor],
        callback: [NSManagedObject] -> Void) {
            let request = NSFetchRequest()
            request.entity = NSEntityDescription.entityForName(entity,
                inManagedObjectContext: managedObjectContext)
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors

            self.managedObjectContext.performBlock {
                let array: [NSManagedObject]
                array = (try? self.managedObjectContext.executeFetchRequest(request) ?? []) as? [NSManagedObject] ?? []
                callback(array)
            }
    }

    // Danger will robinson, this is meant to be inside a managedObjectContext's performBlock block!
    private func coreDataFeedForFeed(feed: Feed) -> CoreDataFeed? {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Feed",
            inManagedObjectContext: managedObjectContext)
        request.predicate = NSPredicate(format: "self == %@", feed.feedID!)
        let objects = (try? self.managedObjectContext.executeFetchRequest(request) ?? []) as? [NSManagedObject] ?? []

        return (objects as? [CoreDataFeed])?.first
    }

    // Danger will robinson, this is meant to be inside a managedObjectContext's performBlock block!
    private func coreDataArticleForArticle(article: Article) -> CoreDataArticle? {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Article",
            inManagedObjectContext: managedObjectContext)
        request.predicate = NSPredicate(format: "self == %@", article.articleID!)
        let objects = (try? self.managedObjectContext.executeFetchRequest(request) ?? []) as? [NSManagedObject] ?? []

        return (objects as? [CoreDataArticle])?.first
    }

    // Danger will robinson, this is meant to be inside a managedObjectContext's performBlock block!
    private func coreDataEnclosureForEnclosure(enclosure: Enclosure) -> CoreDataEnclosure? {
        let request = NSFetchRequest()
        request.entity = NSEntityDescription.entityForName("Enclosure",
            inManagedObjectContext: managedObjectContext)
        request.predicate = NSPredicate(format: "self == %@", enclosure.enclosureID!)
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

            if let feed = article.feed, cdfeed = self.coreDataFeedForFeed(feed) {
                cdarticle.feed = cdfeed
            }

            let _ = try? self.managedObjectContext.save()
        }
    }

    private func updateEnclosure(enclosure: Enclosure) {
        if let cdenclosure = self.coreDataEnclosureForEnclosure(enclosure) {
            cdenclosure.url = enclosure.url.absoluteString
            cdenclosure.kind = enclosure.kind
            cdenclosure.data = enclosure.data
            cdenclosure.downloaded = enclosure.downloaded

            if let article = enclosure.article, cdarticle = self.coreDataArticleForArticle(article) {
                cdenclosure.article = cdarticle
            }

            let _ = try? self.managedObjectContext.save()
        }
    }
}

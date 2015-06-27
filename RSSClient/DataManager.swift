import Foundation
import CoreData
import WebKit
import JavaScriptCore
import Muon

public class DataManager: NSObject {

    // MARK: Public API

    public func allTags() -> [String] {
        let feedsWithTags = DataUtility.feedsWithPredicate(NSPredicate(format: "tags != nil"),
            managedObjectContext: self.backgroundObjectContext)

        let setOfTags = feedsWithTags.reduce(Set<String>()) {set, feed in
            return set.union(Set(feed.tags))
        }

        return Array(setOfTags).sort { return $0.lowercaseString < $1.lowercaseString }
    }

    public func feeds() -> [Feed] {
        return DataUtility.feedsWithPredicate(NSPredicate(value: true),
            managedObjectContext: self.backgroundObjectContext).sort {
                return $0.title < $1.title
        }
    }

    public func feedsMatchingTag(tag: String?) -> [Feed] {
        if let theTag = (tag == "" ? nil : tag) {
            return feeds().filter {
                let tags = $0.tags
                for t in tags {
                    if t.rangeOfString(theTag) != nil {
                        return true
                    }
                }
                return false
            }
        } else {
            return feeds()
        }
    }

    public func newFeed(feedURL: String, completion: (NSError?) -> (Void)) -> Feed {
        let predicate = NSPredicate(format: "url = %@", feedURL)
        if let theFeed = DataUtility.entities("Feed", matchingPredicate: predicate,
            managedObjectContext: self.backgroundObjectContext).last as? CoreDataFeed {
                return Feed(feed: theFeed)
        }
        let cdfeed = newFeed()
        cdfeed.url = feedURL
        let feed = Feed(feed: cdfeed)
        save()
//        NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: cdfeed)
        #if os(iOS)
            let app = UIApplication.sharedApplication()
            app.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        #endif
        self.updateFeeds([feed], completion: completion)
//        self.writeOPML()
        return feed
    }

    public func newQueryFeed(title: String, code: String, summary: String? = nil) -> Feed {
        let predicate = NSPredicate(format: "title = %@", title)
        var feed: CoreDataFeed! = nil
        if let theFeed = DataUtility.entities("Feed", matchingPredicate: predicate,
            managedObjectContext: self.backgroundObjectContext).last as? CoreDataFeed {
                feed = theFeed
        } else {
            feed = newFeed()
            feed.title = title
            feed.query = code
            feed.summary = summary
            save()
//            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        return Feed(feed: feed)
    }

    public func saveFeed(feed: Feed) {
        guard let feedID = feed.feedID where feed.updated else {
            return
        }
        if let cdfeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feedID), managedObjectContext: self.backgroundObjectContext).first as? CoreDataFeed {
            cdfeed.title = feed.title
            cdfeed.url = feed.url?.absoluteString
            cdfeed.summary = feed.summary
            cdfeed.query = feed.query
            cdfeed.tags = feed.tags
            if let waitPeriod = feed.waitPeriod {
                cdfeed.waitPeriod = NSNumber(integer: waitPeriod)
            } else {
                cdfeed.waitPeriod = nil
            }
            if let remainingWait = feed.remainingWait {
                cdfeed.remainingWait = NSNumber(integer: remainingWait)
            } else {
                cdfeed.remainingWait = nil
            }
            cdfeed.image = feed.image

            for article in feed.articles {
                saveArticle(article, feed: cdfeed)
            }
        }
    }

    public func deleteFeed(feed: Feed) {
        guard let feedID = feed.feedID else {
            return
        }
        if let cdfeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feedID), managedObjectContext: self.backgroundObjectContext).first as? CoreDataFeed {
            deleteFeed(cdfeed)
        }
    }

    public func markFeedAsRead(feed: Feed) {
        for article in feed.articles {
            markArticle(article, asRead: true)
        }
    }

    public func deleteArticle(article: Article) {
        guard let articleID = article.articleID else {
            return
        }
        if let cdarticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", articleID), managedObjectContext: self.backgroundObjectContext).first as? CoreDataArticle {
            cdarticle.feed?.removeArticlesObject(cdarticle)
            cdarticle.feed = nil
            self.backgroundObjectContext.deleteObject(cdarticle)
            save()
        }
    }

    public func markArticle(article: Article, asRead read: Bool) {
        guard let articleID = article.articleID else {
            return
        }
        if let cdarticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", articleID), managedObjectContext: self.backgroundObjectContext).first as? CoreDataArticle {
            cdarticle.read = read
            save()
        }
    }

    public func articlesMatchingQuery(query: String, feed: Feed? = nil) -> [Article] {
        return []
    }

    public func updateFeeds(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion)
    }

    public func updateFeedsInBackground(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion, backgroundFetch: true)
    }

    // MARK: Private API

    private func save() {
        do {
            try self.backgroundObjectContext.save()
        } catch {

        }
    }

    private func updateFeeds(feeds: [Feed], backgroundFetch: Bool = false, completion: (NSError?)->(Void) = {_ in }) {
        let feedIds = feeds.filter { $0.url != nil && $0.feedID != nil }.map { $0.feedID! }

        guard let backgroundQueue = self.backgroundQueue, let urlSession = self.urlSession where feedIds.count != 0 else {
            completion(nil);
            return;
        }

        backgroundQueue.addOperationWithBlock {
            let ctx = self.backgroundObjectContext
            let theFeeds = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self in %@", feedIds),
                managedObjectContext: ctx) as? [CoreDataFeed] ?? []
            var feedsLeft = theFeeds.count

            for feed in theFeeds {
                let wait = feed.remainingWait?.integerValue ?? 0
                if wait != 0 {
                    feed.remainingWait = NSNumber(integer: wait - 1)
                    self.save()
                    feedsLeft--
                    if (feedsLeft == 0) {
                        completion(nil)
                        return
                    }
                    continue
                }

                FeedRepository.loadFeed(feed.url!, urlSession: urlSession,
                    operationQueue: backgroundQueue) {muonFeed, error in
                        if let _ = error {
                            self.finishedUpdatingFeed(error, feed: feed, managedObjectContext: ctx,
                                feedsLeft: &feedsLeft, completion: completion)
                        } else if let info = muonFeed {
                            DataUtility.updateFeed(feed, info: info)
                            DataUtility.updateFeedImage(feed, info: info, urlSession: urlSession)
                            for item in info.articles {
                                if let article = self.upsertArticle(item, context: ctx) {
                                    feed.addArticlesObject(article)
                                    article.feed = feed
                                }
                            }
                            self.finishedUpdatingFeed(nil, feed: feed, managedObjectContext: ctx,
                                feedsLeft: &feedsLeft, completion: completion)
                        }
                }
            }
        }
    }

    private func updateFeed(feed: Feed, muonFeed: Muon.Feed) {
        feed.title = muonFeed.title
        let summary: String
        let data = muonFeed.description.dataUsingEncoding(NSUTF8StringEncoding,
            allowLossyConversion: false)!
        let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType]
        do {
            let aString = try NSAttributedString(data: data, options: options,
                documentAttributes: nil)
            summary = aString.string
        } catch _ {
            summary = muonFeed.description
        }
        feed.summary = summary
    }

    private func setApplicationBadgeCount() {
        let num = feeds().filter {
            return !$0.isQueryFeed
        }.reduce(0) {
            return $0 + $1.unreadArticles().count
        }
        #if os(iOS)
            UIApplication.sharedApplication().applicationIconBadgeNumber = num
        #elseif os(OSX)
            NSApplication.sharedApplication().dockTile.badgeLabel = "\(num)"
        #endif
    }

    private func finishedUpdatingFeed(error: NSError?, feed: CoreDataFeed,
        managedObjectContext: NSManagedObjectContext, inout feedsLeft: Int,
        completion: (NSError?) -> (Void)) {
            feedsLeft--
            if error != nil {
                print("Errored loading: \(error)")
            }
            if (error == nil) {
                if feed.waitPeriod == nil || feed.waitPeriod != 0 {
                    feed.waitPeriod = NSNumber(integer: 0)
                    feed.remainingWait = NSNumber(integer: 0)
                    save()
                }
            } else if let err = error where (err.domain == NSURLErrorDomain && err.code > 0) {
                let waitPeriod = (feed.waitPeriod?.integerValue ?? 0) + 1
                feed.waitPeriod = NSNumber(integer: waitPeriod)
                feed.remainingWait = NSNumber(integer: max(0, waitPeriod - 2))
                save()
            }
            if feedsLeft == 0 {
                if backgroundObjectContext.hasChanges {
                    do {
                        try backgroundObjectContext.save()
                    } catch _ {
                    }
                }
                self.save()
                mainQueue?.addOperationWithBlock {
                    completion(error)
                    self.setApplicationBadgeCount()
                }
            }
    }

    private func newFeed() -> CoreDataFeed {
        let entityDescription = NSEntityDescription.entityForName("Feed", inManagedObjectContext: backgroundObjectContext)!
        return CoreDataFeed(entity: entityDescription, insertIntoManagedObjectContext: backgroundObjectContext)
    }

    private func deleteFeed(feed: CoreDataFeed) {
        for article in feed.articles {
            self.backgroundObjectContext.deleteObject(article)
        }
        self.backgroundObjectContext.deleteObject(feed)
        do {
            try self.backgroundObjectContext.save()
        } catch _ {
        }
        if (feeds().count == 0) {
            #if os(iOS)
                let app = UIApplication.sharedApplication()
                app.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
            #endif
        }
//        self.writeOPML()
    }

    // MARK: Articles

    private func saveArticle(article: Article, feed: CoreDataFeed) {
        guard let articleID = article.articleID where article.updated else {
            return
        }
        if let cdarticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", articleID), managedObjectContext: self.backgroundObjectContext).first as? CoreDataArticle {
            cdarticle.title = article.title
            cdarticle.link = article.link?.absoluteString
            cdarticle.summary = article.summary
            cdarticle.author = article.author
            cdarticle.published = article.published
            cdarticle.updatedAt = article.updatedAt
            cdarticle.content = article.content
            cdarticle.read = article.read
            cdarticle.flags = article.flags
            cdarticle.feed = feed

            let feedarticles = feed.articles.map { $0.objectID }
            if let articleID = article.articleID {
                if !feedarticles.contains(articleID) {
                    feed.addArticlesObject(cdarticle)
                }
            }
        }
    }

    private func upsertArticle(item: Muon.Article, context ctx: NSManagedObjectContext! = nil) -> CoreDataArticle? {
        let predicate = NSPredicate(format: "link = %@", item.link ?? "")
        if let article = DataUtility.entities("Article", matchingPredicate: predicate,
            managedObjectContext: ctx).last as? CoreDataArticle {
                if article.updatedAt != item.updated {
                    DataUtility.updateArticle(article, item: item)

                    for enc in item.enclosures {
                        DataUtility.insertEnclosureFromItem(enc, article: article)
                    }
                }
                return nil
        } else {
            // create
            let article = NSEntityDescription.insertNewObjectForEntityForName("Article",
                inManagedObjectContext: ctx) as! CoreDataArticle
            DataUtility.updateArticle(article, item: item)

            for enclosure in item.enclosures {
                DataUtility.insertEnclosureFromItem(enclosure, article: article)
            }
            return article
        }
    }

    private func readArticle(article: CoreDataArticle, read: Bool = true) {
        article.read = read
        do {
            try article.managedObjectContext?.save()
        } catch _ {
        }
        setApplicationBadgeCount()
    }

    private func readArticles(articles: [CoreDataArticle], read: Bool = true) {
        for article in articles {
            article.read = read
        }
        do {
            try articles.first?.managedObjectContext?.save()
        } catch _ {
        }
        setApplicationBadgeCount()
    }

    private func newArticle() -> CoreDataArticle {
        return NSEntityDescription.insertNewObjectForEntityForName("Article",
            inManagedObjectContext: self.backgroundObjectContext) as! CoreDataArticle
    }

    private lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = NSBundle(forClass: self.classForCoder).URLForResource("RSSClient", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    private lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let storeURL = NSURL.fileURLWithPath(documentsDirectory().stringByAppendingPathComponent("RSSClient.sqlite"))
        let persistentStore = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        var error: NSError? = nil
        var options: [String: AnyObject] = [NSMigratePersistentStoresAutomaticallyOption: true,
                                            NSInferMappingModelAutomaticallyOption: true]
        do {
            try persistentStore.addPersistentStoreWithType(NSSQLiteStoreType,
                configuration: self.managedObjectModel.configurations.last,
                URL: storeURL, options: options)
        } catch var error1 as NSError {
            error = error1
        } catch {
            fatalError()
        }
        if (error != nil) {
            do {
                try NSFileManager.defaultManager().removeItemAtURL(storeURL)
            } catch _ {
            }
            error = nil
            do {
                try persistentStore.addPersistentStoreWithType(NSSQLiteStoreType,
                    configuration: self.managedObjectModel.configurations.last,
                    URL: storeURL, options: options)
            } catch var error1 as NSError {
                error = error1
            } catch {
                fatalError()
            }
            if let err = error {
                print("Fatal error adding persistent data store: \(err)")
                fatalError()
            }
        }
        return persistentStore
    }()

    public lazy var backgroundObjectContext: NSManagedObjectContext = {
        let ctx = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        ctx.persistentStoreCoordinator = self.persistentStoreCoordinator
        return ctx
    }()

    private lazy var urlSession: NSURLSession? = {
        return self.injector?.create(NSURLSession.self) as? NSURLSession
    }()

    private lazy var mainQueue: NSOperationQueue? = {
        return self.injector?.create(kMainQueue) as? NSOperationQueue
    }()

    private lazy var backgroundQueue: NSOperationQueue? = {
        return self.injector?.create(kBackgroundQueue) as? NSOperationQueue
    }()
}

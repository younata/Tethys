import Foundation
import CoreData
import WebKit
import JavaScriptCore
import Muon
import CoreSpotlight
import MobileCoreServices

private func loadFeed(url: String, urlSession: NSURLSession, operationQueue: NSOperationQueue, callback: (Muon.Feed?, NSError?) -> (Void)) {
    operationQueue.addOperationWithBlock {
        guard let url = NSURL(string: url) else {
            callback(nil, NSError(domain: "", code: 0, userInfo: [:]))
            return
        }
        urlSession.dataTaskWithURL(url) {data, response, error in
            if let err = error {
                callback(nil, err)
            } else if let data = data, let s = NSString(data: data, encoding: NSUTF8StringEncoding) as? String {
                let feedParser = Muon.FeedParser(string: s)
                feedParser.success { callback($0, nil) }.failure { callback(nil, $0) }
                operationQueue.addOperation(feedParser)
            } else {
                let error: NSError
                if let response = response as? NSHTTPURLResponse where response.statusCode != 200 {
                    error = NSError(domain: response.URL?.absoluteString ?? "com.rachelbrindle.rssclient.unknown", code: response.statusCode, userInfo: [NSLocalizedFailureReasonErrorKey: NSHTTPURLResponse.localizedStringForStatusCode(response.statusCode)])
                } else {
                    error = NSError(domain: "com.rachelbrindle.rssclient.unknown", code: 1, userInfo: [NSLocalizedFailureReasonErrorKey: "Unknown"])
                }
                callback(nil, error)
            }
        }
    }
}

public class DataManager: NSObject {

    // MARK: Properties

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

    private lazy var searchIndex: SearchIndex? = {
        return self.injector?.create(SearchIndex.self) as? SearchIndex
    }()

    // MARK: Public API

    public func newFeed(feedURL: String, completion: (NSError?) -> (Void)) -> Feed {
        let predicate = NSPredicate(format: "url = %@", feedURL)
        if let theFeed = DataUtility.entities("Feed", matchingPredicate: predicate,
            managedObjectContext: self.backgroundObjectContext).last as? CoreDataFeed {
                return Feed(feed: theFeed)
        }
        let cdfeed = newFeed()
        cdfeed.url = feedURL
        save()
//        #if os(iOS)
//            let app = UIApplication.sharedApplication()
//            app.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
//        #endif
        var feedsLeft = 1
        self.updateCoreDataFeed(cdfeed, feedsLeft: &feedsLeft, completion: completion)
        return Feed(feed: cdfeed)
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
        }
        return Feed(feed: feed)
    }

    public func updateFeeds(completion: (NSError?)->(Void)) {
        updateFeeds([], completion: completion)
    }

    public func updateFeedsInBackground(completion: (NSError?)->(Void)) {
        updateFeeds([], completion: completion, backgroundFetch: true)
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

        guard let backgroundQueue = self.backgroundQueue where feedIds.count != 0 else {
            completion(nil);
            return;
        }

        backgroundQueue.addOperationWithBlock {
            let ctx = self.backgroundObjectContext
            let theFeeds = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self in %@", feedIds),
                managedObjectContext: ctx) as? [CoreDataFeed] ?? []
            var feedsLeft = theFeeds.count

            for feed in theFeeds {
                self.updateCoreDataFeed(feed, feedsLeft: &feedsLeft, completion: completion)
            }
        }
    }

    private func updateCoreDataFeed(feed: CoreDataFeed, inout feedsLeft: Int, completion: (NSError?)->(Void) = {_ in }) {
        guard let backgroundQueue = self.backgroundQueue, let urlSession = self.urlSession else {
            completion(nil);
            return;
        }
        backgroundQueue.addOperationWithBlock {
            let wait = feed.remainingWaitInt
            if wait != 0 {
                feed.remainingWaitInt = wait - 1
                self.save()
                feedsLeft--
                if (feedsLeft == 0) {
                    completion(nil)
                }
                return
            }

            loadFeed(feed.url!, urlSession: urlSession,
                operationQueue: backgroundQueue) {muonFeed, error in
                    let ctx = self.backgroundObjectContext
                    if let _ = error {
                        self.finishedUpdatingFeed(error, feed: feed, managedObjectContext: ctx,
                            feedsLeft: &feedsLeft, completion: completion)
                    } else if let info = muonFeed {
                        DataUtility.updateFeed(feed, info: info)
                        DataUtility.updateFeedImage(feed, info: info, urlSession: urlSession)

                        var articles: [CoreDataArticle] = [] // caching for batch insert
                        for item in info.articles {
                            if let article = self.upsertArticle(item, context: ctx) {
                                article.feed = feed

                                articles.append(article)
                            }
                        }

                        if #available(iOS 9.0, *) {
                            if let searchIndex = self.searchIndex {
                                self.save()
                                let items: [CSSearchableItem] = articles.map {article in
                                    let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeHTML as String)
                                    attributes.title = article.title
                                    attributes.textContent = article.content ?? article.summary
                                    attributes.timestamp = article.updatedAt ?? article.published
                                    attributes.creator = article.author
                                    attributes.contentURL = NSURL(string: article.link ?? "")
                                    attributes.contentDescription = article.summary
                                    attributes.keywords = article.flags
                                    let identifier = article.objectID.URIRepresentation().absoluteString
                                    let feedTitle = article.feed?.title ?? "feed"
                                    let articleTitle = article.title ?? "article"
                                    let domain = "com.rachelbrindle.rssclient.\(feedTitle).\(articleTitle)"
                                    let item = CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: domain, attributeSet: attributes)
                                    return item
                                }
                                searchIndex.addItemsToIndex(items, completionHandler: {_ in })
                            }
                        }
                        self.finishedUpdatingFeed(nil, feed: feed, managedObjectContext: ctx,
                            feedsLeft: &feedsLeft, completion: completion)
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
//        let num = feeds().filter {
//            return !$0.isQueryFeed
//        }.reduce(0) {
//            return $0 + $1.unreadArticles().count
//        }
//        #if os(iOS)
//            UIApplication.sharedApplication().applicationIconBadgeNumber = num
//        #elseif os(OSX)
//            NSApplication.sharedApplication().dockTile.badgeLabel = "\(num)"
//        #endif
    }

    private func finishedUpdatingFeed(error: NSError?, feed: CoreDataFeed,
        managedObjectContext: NSManagedObjectContext, inout feedsLeft: Int,
        completion: (NSError?) -> (Void)) {
            feedsLeft--
            if (error == nil) {
                if feed.waitPeriod != 0 {
                    feed.waitPeriod = 0
                    feed.remainingWait = 0
                    save()
                }
            } else if let err = error where (err.domain == NSURLErrorDomain && err.code > 0) {
                let waitPeriod = feed.waitPeriodInt + 1
                feed.waitPeriodInt = waitPeriod
                feed.remainingWait = max(0, waitPeriod - 2)
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
        save()
//        if (feeds().count == 0) {
//            #if os(iOS)
//                let app = UIApplication.sharedApplication()
//                app.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
//            #endif
//        }
//        self.writeOPML()
    }

    // MARK: Articles

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

    private func newArticle() -> CoreDataArticle {
        return NSEntityDescription.insertNewObjectForEntityForName("Article",
            inManagedObjectContext: self.backgroundObjectContext) as! CoreDataArticle
    }
}

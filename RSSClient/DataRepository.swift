import Foundation
import Ra
import CoreSpotlight
import CoreData
#if os(iOS)
    import MobileCoreServices
#endif

public protocol DataRetriever {
    func allTags(callback: ([String]) -> (Void))
    func feeds(callback: ([Feed]) -> (Void))
    func feedsMatchingTag(tag: String?, callback: ([Feed]) -> (Void))
    func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void))
}

public protocol DataWriter {
    func newFeed(callback: (Feed) -> (Void))
    func saveFeed(feed: Feed)
    func deleteFeed(feed: Feed)
    func markFeedAsRead(feed: Feed)

    func saveArticle(article: Article)
    func deleteArticle(article: Article)
    func markArticle(article: Article, asRead: Bool)

    func updateFeeds(callback: ([Feed], NSError?) -> (Void))
}

internal class DataRepository: DataRetriever, DataWriter {
    private let objectContext: NSManagedObjectContext
    private let mainQueue: NSOperationQueue
    private let backgroundQueue: NSOperationQueue
    private let opmlManager: OPMLManager

    private let searchIndex: SearchIndex?

    internal init(objectContext: NSManagedObjectContext, mainQueue: NSOperationQueue, backgroundQueue: NSOperationQueue, opmlManager: OPMLManager, searchIndex: SearchIndex?) {
        self.objectContext = objectContext
        self.mainQueue = mainQueue
        self.backgroundQueue = backgroundQueue
        self.opmlManager = opmlManager
        self.searchIndex = searchIndex
    }

    //MARK: - DataRetriever

    internal func allTags(callback: ([String]) -> (Void)) {
        self.backgroundQueue.addOperationWithBlock {
            let feedsWithTags = DataUtility.feedsWithPredicate(NSPredicate(format: "tags != nil"), managedObjectContext: self.objectContext)

            let setOfTags = feedsWithTags.reduce(Set<String>()) {set, feed in
                return set.union(Set(feed.tags))
            }
            
            let tags = Array(setOfTags).sort { return $0.lowercaseString < $1.lowercaseString }
            self.mainQueue.addOperationWithBlock {
                callback(tags)
            }
        }
    }

    internal func feeds(callback: ([Feed]) -> (Void)) {
        allFeedsOnBackgroundQueue { feeds in
            self.mainQueue.addOperationWithBlock {
                callback(feeds)
            }
        }
    }

    internal func feedsMatchingTag(tag: String?, callback: ([Feed]) -> (Void)) {
        if let theTag = tag where !theTag.isEmpty {
            self.feeds { allFeeds in
                let feeds = allFeeds.filter { feed in
                    let tags = feed.tags
                    for t in tags {
                        if t.rangeOfString(theTag) != nil {
                            return true
                        }
                    }
                    return false
                }
                callback(feeds)
            }
        } else {
            feeds(callback)
        }
    }

    internal func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        allFeedsOnBackgroundQueue { feeds in
            self.mainQueue.addOperationWithBlock {
                callback([])
            }
        }
    }

    // MARK: Private (DataRetriever)

    private func allFeedsOnBackgroundQueue(callback: ([Feed] -> (Void))) {
        self.backgroundQueue.addOperationWithBlock {
            let feeds = DataUtility.feedsWithPredicate(NSPredicate(value: true),
                managedObjectContext: self.objectContext).sort {
                    return $0.title < $1.title
            }
            callback(feeds)
        }
    }

    // MARK: DataWriter

    internal func newFeed(callback: (Feed) -> (Void)) {

    }

    internal func saveFeed(feed: Feed) {
        guard let feedID = feed.feedID where feed.updated else {
            return
        }
        self.backgroundQueue.addOperationWithBlock {
            if let cdfeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feedID), managedObjectContext: self.objectContext).first as? CoreDataFeed {
                cdfeed.title = feed.title
                cdfeed.url = feed.url?.absoluteString
                cdfeed.summary = feed.summary
                cdfeed.query = feed.query
                cdfeed.tags = feed.tags
                if let waitPeriod = feed.waitPeriod {
                    cdfeed.waitPeriod = waitPeriod
                } else {
                    cdfeed.waitPeriod = 0
                }
                if let remainingWait = feed.remainingWait {
                    cdfeed.remainingWait = remainingWait
                } else {
                    cdfeed.remainingWait = 0
                }
                cdfeed.image = feed.image

                for article in feed.articles {
                    self.saveArticle(article, feed: cdfeed)
                }
            }
        }
    }

    internal func deleteFeed(feed: Feed) {
        guard let feedID = feed.feedID else {
            return
        }
        self.backgroundQueue.addOperationWithBlock {
            if let cdfeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feedID), managedObjectContext: self.objectContext).first as? CoreDataFeed {
                let articleIDsToDelete = cdfeed.articles.map {
                    return $0.objectID.URIRepresentation().absoluteString
                }
                for article in cdfeed.articles {
                    self.objectContext.deleteObject(article)
                }
                self.objectContext.deleteObject(cdfeed)
                if #available(iOS 9.0, *) {
                    self.searchIndex?.deleteIdentifierFromIndex(articleIDsToDelete) {error in
                    }
                }
            }
            self.opmlManager.writeOPML()
        }
    }

    internal func markFeedAsRead(feed: Feed) {
        self.backgroundQueue.addOperationWithBlock {
            for article in feed.articles {
                self.privateMarkArticle(article, asRead: true)
            }
        }
    }

    internal func saveArticle(article: Article) {
        guard let feedID = article.feed?.feedID where article.updated else {
            return
        }
        self.backgroundQueue.addOperationWithBlock {
            if let cdfeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feedID), managedObjectContext: self.objectContext).first as? CoreDataFeed {
                self.saveArticle(article, feed: cdfeed)
            }
        }
    }

    internal func deleteArticle(article: Article) {
        guard let articleID = article.articleID else {
            return
        }
        self.backgroundQueue.addOperationWithBlock {
            if let cdarticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", articleID), managedObjectContext: self.objectContext).first as? CoreDataArticle {
                let identifier = cdarticle.objectID.URIRepresentation().absoluteString
                self.objectContext.deleteObject(cdarticle)
                if #available(iOS 9.0, *) {
                    self.searchIndex?.deleteIdentifierFromIndex([identifier]) {error in
                    }
                }
            }
        }
    }

    internal func markArticle(article: Article, asRead: Bool) {
        self.backgroundQueue.addOperationWithBlock {
            self.privateMarkArticle(article, asRead: asRead)
        }
    }

    internal func updateFeeds(callback: ([Feed], NSError?) -> (Void)) {

    }

    //MARK: Private (DataWriter)

    internal func synchronousNewFeed() -> Feed {
        // Do not call this on the main thread
        let entityDescription = NSEntityDescription.entityForName("Feed", inManagedObjectContext: self.objectContext)!
        let cdfeed = CoreDataFeed(entity: entityDescription, insertIntoManagedObjectContext: self.objectContext)
        return Feed(feed: cdfeed)
    }

    private func save() {
        do {
            try self.objectContext.save()
        } catch {}
    }

    private func saveArticle(article: Article, feed: CoreDataFeed) {
        guard let articleID = article.articleID else {
            return
        }
        if let cdarticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", articleID), managedObjectContext: self.objectContext).first as? CoreDataArticle {
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

            if #available(iOS 9.0, *) {
                let identifier = cdarticle.objectID.URIRepresentation().absoluteString

                let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeHTML as String)
                attributes.title = article.title
                attributes.contentDescription = article.summary
                let feedTitleWords = article.feed?.title.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                attributes.keywords = ["article"] + (feedTitleWords ?? [])
                attributes.URL = article.link
                attributes.timestamp = article.updatedAt ?? article.published
                attributes.authorNames = [article.author]

                let item = CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: nil, attributeSet: attributes)
                item.expirationDate = NSDate.distantFuture()
                self.searchIndex?.addItemsToIndex([item]) {error in
                }
            }
        }
    }

    private func privateMarkArticle(article: Article, asRead read: Bool) {
        guard let articleID = article.articleID else {
            return
        }
        if let cdarticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", articleID), managedObjectContext: self.objectContext).first as? CoreDataArticle {
            cdarticle.read = read
            save()
        }
    }
}
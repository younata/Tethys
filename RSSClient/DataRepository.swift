import Foundation
import Ra
import CoreSpotlight
import CoreData
import Muon
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

    func updateFeeds(callback: ([Feed], [NSError]) -> (Void))
}

internal class DataRepository: DataRetriever, DataWriter {
    private let objectContext: NSManagedObjectContext
    private let mainQueue: NSOperationQueue
    private let backgroundQueue: NSOperationQueue
    private let opmlManager: OPMLManager
    private let urlSession: NSURLSession

    private let searchIndex: SearchIndex?

    internal init(objectContext: NSManagedObjectContext, mainQueue: NSOperationQueue, backgroundQueue: NSOperationQueue,
                  opmlManager: OPMLManager, urlSession: NSURLSession, searchIndex: SearchIndex?) {
        self.objectContext = objectContext
        self.mainQueue = mainQueue
        self.backgroundQueue = backgroundQueue
        self.opmlManager = opmlManager
        self.urlSession = urlSession
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
        guard let _ = feed.feedID where feed.updated else {
            return
        }
        self.backgroundQueue.addOperationWithBlock {
            self.synchronousSaveFeed(feed)
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

    internal func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        self.allFeedsOnBackgroundQueue {feeds in
            var feedsLeft = feeds.count
            for feed in feeds {
                guard let url = feed.url where feed.remainingWait == 0 else {
                    feed.remainingWait--
                    self.synchronousSaveFeed(feed)
                    feedsLeft--
                    continue
                }
                var errors: [NSError] = []
                var feeds: [Feed] = []
                loadFeed(url, urlSession: self.urlSession, queue: self.backgroundQueue) {muonFeed, error in
                    if let err = error {
                        if err.domain == "com.rachelbrindle.rssclient.server" {
                            feed.remainingWait++
                            self.synchronousSaveFeed(feed)
                        }
                        errors.append(err)
                    }
                    if let item = muonFeed {
                        self.updateFeed(feed, muonFeed: item)
                        self.updateFeedImage(feed, muonFeed: item)

                        for muonArticle in item.articles {
                            if let article = self.upsertArticle(muonArticle) {
                                feed.addArticle(article)
                            }
                        }

                        self.synchronousSaveFeed(feed)

                        feeds.append(feed)
                    }

                    feedsLeft--
                    if (feedsLeft == 0) {
                        self.mainQueue.addOperationWithBlock {
                            callback(feeds, errors)
                        }
                    }
                }
            }
        }
    }

    //MARK: Private (DataWriter)

    internal func synchronousNewFeed() -> Feed {
        // Do not call this on the main thread
        let entityDescription = NSEntityDescription.entityForName("Feed", inManagedObjectContext: self.objectContext)!
        let cdfeed = CoreDataFeed(entity: entityDescription, insertIntoManagedObjectContext: self.objectContext)
        return Feed(feed: cdfeed)
    }

    private func upsertArticle(muonArticle: Muon.Article) -> Article? {
        let predicate = NSPredicate(format: "link = %@", muonArticle.link ?? "")
        if let article = DataUtility.entities("Article", matchingPredicate: predicate,
            managedObjectContext: self.objectContext).last as? CoreDataArticle {
                if article.updatedAt != muonArticle.updated {
                    DataUtility.updateArticle(article, item: muonArticle)

                }
                return nil
        } else {
            // create
            let article = NSEntityDescription.insertNewObjectForEntityForName("Article",
                inManagedObjectContext: self.objectContext) as! CoreDataArticle
            DataUtility.updateArticle(article, item: muonArticle)
            return Article(article: article, feed: nil)
        }
    }

    private func save() {
        do {
            try self.objectContext.save()
        } catch {}
    }

    private func synchronousSaveFeed(feed: Feed) {
        // Do not call this on the main thread
        guard let feedID = feed.feedID where feed.updated else {
            return
        }
        if let cdfeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feedID), managedObjectContext: self.objectContext).first as? CoreDataFeed {
            cdfeed.title = feed.title
            cdfeed.url = feed.url?.absoluteString
            cdfeed.summary = feed.summary
            cdfeed.query = feed.query
            cdfeed.tags = feed.tags
            cdfeed.waitPeriodInt = feed.waitPeriod
            cdfeed.remainingWaitInt = feed.remainingWait
            cdfeed.image = feed.image

            for article in feed.articles {
                self.saveArticle(article, feed: cdfeed)
            }
        }
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

    private func updateFeedImage(feed: Feed, muonFeed: Muon.Feed) {
        if let imageURL = muonFeed.imageURL where feed.image == nil {
            urlSession.dataTaskWithURL(imageURL) {data, _, error in
                if error != nil {
                    return
                }
                if let d = data {
                    if let image = Image(data: d) {
                        feed.image = image
                        self.synchronousSaveFeed(feed)
                    }
                }
            }?.resume()
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

private func loadFeed(url: NSURL, urlSession: NSURLSession, queue: NSOperationQueue, callback: (Muon.Feed?, NSError?) -> (Void)) {
    urlSession.dataTaskWithURL(url) {data, response, error in
        if let error = error {
            callback(nil, error)
        } else if let data = data, string = NSString(data: data, encoding: NSUTF8StringEncoding) as? String {
            let feedParser = Muon.FeedParser(string: string)
            feedParser.success { callback($0, nil) }.failure { callback(nil, $0) }
            queue.addOperation(feedParser)
        } else {
            let error: NSError
            if let response = response as? NSHTTPURLResponse where response.statusCode != 200 {
                error = NSError(domain: "com.rachelbrindle.rssclient.server", code: response.statusCode, userInfo: [NSLocalizedFailureReasonErrorKey: NSHTTPURLResponse.localizedStringForStatusCode(response.statusCode)])
            } else {
                error = NSError(domain: "com.rachelbrindle.rssclient.unknown", code: 1, userInfo: [NSLocalizedFailureReasonErrorKey: "Unknown"])
            }
            callback(nil, error)
        }
    }
}
import Foundation
import Ra

public protocol DataRetriever {
    func allTags(callback: ([String]) -> (Void))
    func feeds(callback: ([Feed]) -> (Void))
    func feedsMatchingTag(tag: String?, callback: ([Feed]) -> (Void))
    func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void))
}

public protocol DataWriter {
    func saveFeed(feed: Feed)
    func deleteFeed(feed: Feed)
    func markFeedAsRead(feed: Feed)

    func saveArticle(article: Article)
    func deleteArticle(article: Article)
    func markArticle(article: Article, asRead: Bool)

    func updateFeeds(callback: (NSError?) -> (Void))
}

public class FeedRepository: DataRetriever, DataWriter {
    private let objectContext: NSManagedObjectContext
    private let mainQueue: NSOperationQueue
    private let backgroundQueue: NSOperationQueue

    public init(objectContext: NSManagedObjectContext, mainQueue: NSOperationQueue, backgroundQueue: NSOperationQueue) {
        self.objectContext = objectContext
        self.mainQueue = mainQueue
        self.backgroundQueue = backgroundQueue
    }

    //MARK: - DataRetriever

    public func allTags(callback: ([String]) -> (Void)) {
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

    public func feeds(callback: ([Feed]) -> (Void)) {
        allFeedsOnBackgroundQueue { feeds in
            self.mainQueue.addOperationWithBlock {
                callback(feeds)
            }
        }
    }

    public func feedsMatchingTag(tag: String?, callback: ([Feed]) -> (Void)) {
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

    public func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
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

    public func saveFeed(feed: Feed) {

    }

    public func deleteFeed(feed: Feed) {

    }

    public func markFeedAsRead(feed: Feed) {

    }

    public func saveArticle(article: Article) {

    }

    public func deleteArticle(article: Article) {

    }

    public func markArticle(article: Article, asRead: Bool) {

    }

    public func updateFeeds(callback: (NSError?) -> (Void)) {

    }
}
import Foundation
import CBGPromise
@testable import rNewsKit

class FakeFeedRepository: FeedRepository {
    init() {}

    var _databaseUpdateAvailable = false
    func databaseUpdateAvailable() -> Bool {
        return self._databaseUpdateAvailable
    }

    var performDatabaseUpdatesProgress: (Double -> Void)?
    var perfomDatabaseUpdatesCallback: (Void -> Void)?
    func performDatabaseUpdates(progress: Double -> Void, callback: Void -> Void) {
        self.performDatabaseUpdatesProgress = progress
        self.perfomDatabaseUpdatesCallback = callback
    }

    var tagsList: [String] = []
    func allTags(callback: ([String]) -> (Void)) {
        callback(tagsList)
    }

    var feedsList: [Feed]? = nil
    var didAskForFeeds = false
    var feedsCallback: (([Feed]) -> (Void))? = nil
    func feeds(callback: ([Feed]) -> (Void)) {
        didAskForFeeds = true
        feedsCallback = callback
        if let feedsList = feedsList {
            return callback(feedsList)
        }
    }

    func feedsMatchingTag(tag: String?, callback: ([Feed]) -> (Void)) {
        didAskForFeeds = true
        feedsCallback = callback
        guard let theTag = tag, feedslist = feedsList where !theTag.isEmpty else {
            return self.feeds(callback)
        }

        let feeds = feedslist.filter {feed in
            let tags = feed.tags
            for t in tags {
                if t.rangeOfString(theTag) != nil {
                    return true
                }
            }
            return false
        }

        return callback(feeds)
    }

    var articlesOfFeedList = Array<Article>()
    func articlesOfFeeds(feeds: [Feed], matchingSearchQuery: String, callback: (DataStoreBackedArray<Article>) -> (Void)) {
        return callback(DataStoreBackedArray(articlesOfFeedList))
    }

    var articlesList: [Article] = []
    func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        return callback(articlesList)
    }

    // MARK: DataWriter

    let subscribers = NSHashTable.weakObjectsHashTable()
    var subscribersArray: [DataSubscriber] {
        return self.subscribers.allObjects.flatMap { $0 as? DataSubscriber }
    }
    func addSubscriber(subscriber: DataSubscriber) {
        self.subscribers.addObject(subscriber)
    }

    var newFeedCallback: (Feed) -> (Void) = {_ in }
    var didCreateFeed = false
    func newFeed(callback: (Feed) -> (Void)) {
        didCreateFeed = true
        self.newFeedCallback = callback
    }

    var lastSavedFeed: Feed? = nil
    func saveFeed(feed: Feed) {
        lastSavedFeed = feed
    }

    var lastDeletedFeed: Feed? = nil
    var deletedFeeds = Array<Feed>()
    func deleteFeed(feed: Feed) {
        deletedFeeds.append(feed)
        lastDeletedFeed = feed
    }

    var lastFeedMarkedRead: Feed? = nil
    var markedReadFeeds = Array<Feed>()
    var markedReadPromise: Promise<Int>? = nil
    func markFeedAsRead(feed: Feed) -> Future<Int> {
        markedReadFeeds.append(feed)
        lastFeedMarkedRead = feed
        self.markedReadPromise = Promise<Int>()
        return self.markedReadPromise!.future
    }

    func saveArticle(article: Article) {
        fatalError("should not have called saveArticle?")
    }

    var lastDeletedArticle: Article? = nil
    func deleteArticle(article: Article) {
        lastDeletedArticle = article
        article.feed?.removeArticle(article)
        article.feed = nil
    }

    var lastArticleMarkedRead: Article? = nil
    func markArticle(article: Article, asRead read: Bool) {
        lastArticleMarkedRead = article
        article.read = read
    }

    var didUpdateFeeds = false
    var updateFeedsCompletion: ([Feed], [NSError]) -> (Void) = {_ in }
    func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = callback
    }

    var didUpdateFeed: Feed? = nil
    var updateSingleFeedCallback: (Feed, NSError?) -> (Void) = {_ in }
    func updateFeed(feed: Feed, callback: (Feed?, NSError?) -> (Void)) {
        didUpdateFeed = feed
        updateSingleFeedCallback = callback
    }
}

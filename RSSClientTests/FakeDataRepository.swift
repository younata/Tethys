import Foundation
import CoreData
@testable import rNewsKit

class FakeDataRepository : DataRepository {

    init() {
        super.init(objectContext: NSManagedObjectContext(), mainQueue: NSOperationQueue(), backgroundQueue: NSOperationQueue(), opmlManager: OPMLManagerMock(), searchIndex: nil)
    }

    var newFeedCompletion : (Feed) -> Void = {_ in }
    override func newFeed(callback: (Feed) -> (Void)) {
        newFeedCompletion = callback
    }

    var lastSavedFeed: Feed? = nil
    override func saveFeed(feed: Feed) {
        lastSavedFeed = feed
    }

    var lastDeletedFeed: Feed? = nil
    override func deleteFeed(feed: Feed) {
        lastDeletedFeed = feed
    }

    var lastFeedMarkedRead: Feed? = nil
    override func markFeedAsRead(feed: Feed) {
        lastFeedMarkedRead = feed
    }

    var tagsList: [String] = []
    override func allTags(callback: ([String]) -> (Void)) {
        callback(tagsList)
    }

    var feedsList: [Feed] = []
    override func feeds(callback: ([Feed]) -> (Void)) {
        return callback(feedsList)
    }

    var articlesList: [Article] = []
    override func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        return callback(articlesList)
    }

    var lastArticleMarkedRead: Article? = nil
    override func markArticle(article: Article, asRead read: Bool) {
        lastArticleMarkedRead = article
        article.read = read
    }

    var lastDeletedArticle: Article? = nil
    override func deleteArticle(article: Article) {
        lastDeletedArticle = article
        article.feed?.removeArticle(article)
        article.feed = nil
    }

    var didUpdateFeeds = false
    var updateFeedsCompletion: ([Feed], NSError?) -> (Void) = {_ in }
    override func updateFeeds(callback: ([Feed], NSError?) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = callback
    }
}
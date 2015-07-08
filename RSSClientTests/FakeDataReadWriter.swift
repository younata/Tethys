import Foundation
import rNewsKit

class FakeDataReadWriter : DataRetriever, DataWriter {
    init() {}

    var tagsList: [String] = []
    func allTags(callback: ([String]) -> (Void)) {
        callback(tagsList)
    }

    var feedsList: [Feed] = []
    func feeds(callback: ([Feed]) -> (Void)) {
        return callback(feedsList)
    }

    func feedsMatchingTag(tag: String?, callback: ([Feed]) -> (Void)) {
        return callback(feedsList)
    }

    var articlesList: [Article] = []
    func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        return callback(articlesList)
    }

    // MARK: DataWriter

    var newFeedCallback: (Feed) -> (Void) = {_ in }
    func newFeed(callback: (Feed) -> (Void)) {
        self.newFeedCallback = callback
    }

    var lastSavedFeed: Feed? = nil
    func saveFeed(feed: Feed) {
        lastSavedFeed = feed
    }

    var lastDeletedFeed: Feed? = nil
    func deleteFeed(feed: Feed) {
        lastDeletedFeed = feed
    }

    var lastFeedMarkedRead: Feed? = nil
    func markFeedAsRead(feed: Feed) {
        lastFeedMarkedRead = feed
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
}

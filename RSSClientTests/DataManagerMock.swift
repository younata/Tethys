import Foundation
import rNews

class DataManagerMock : DataManager {
    var newFeedURL: String? = nil
    var newFeedCompletion : (NSError?) -> Void = {_ in }
    override func newFeed(feedURL: String, completion: (NSError?) -> (Void)) -> Feed {
        newFeedURL = feedURL
        newFeedCompletion = completion
        return Feed(title: "", url: NSURL(string: feedURL), summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
    }

    override func newQueryFeed(title: String, code: String, summary: String?) -> Feed {
        return Feed(title: title, url: nil, summary: summary ?? "", query: code, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
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
    override func allTags() -> [String] {
        return tagsList
    }

    var feedsList: [Feed] = []
    override func feeds() -> [Feed] {
        return feedsList
    }

    var articlesList: [Article] = []
    override func articlesMatchingQuery(query: String, feed: Feed? = nil) -> [Article] {
        return articlesList
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
    var updateFeedsCompletion: (NSError?) -> (Void) = {_ in }
    override func updateFeeds(completion: (NSError?) -> (Void)) {
        didUpdateFeeds = true
        updateFeedsCompletion = completion
    }

    var updateFeedsInBackgroundCalled: Bool = false
    override func updateFeedsInBackground(completion: (NSError?) -> (Void)) {
        updateFeedsInBackgroundCalled = true
        self.updateFeeds(completion)
    }
}
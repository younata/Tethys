@testable import rNewsKit

class FakeDataSubscriber: NSObject, DataSubscriber {
    var markedArticles: [Article]? = nil
    var read: Bool? = nil
    func markedArticles(articles: [Article], asRead: Bool) {
        markedArticles = articles
        read = asRead
    }

    var deletedArticle: Article? = nil
    func deletedArticle(article: Article) {
        deletedArticle = article
    }

    var deletedFeed: Feed? = nil
    var deletedFeedsLeft: Int? = nil
    func deletedFeed(feed: Feed, feedsLeft: Int) {
        deletedFeed = feed
        deletedFeedsLeft = feedsLeft
    }

    var didStartUpdatingFeeds = false
    func willUpdateFeeds() {
        didStartUpdatingFeeds = true
    }

    var updateFeedsProgressFinished = 0
    var updateFeedsProgressTotal = 0
    var didUpdateFeedsArgs: [(Int, Int)] = []
    func didUpdateFeedsProgress(finished: Int, total: Int) {
        updateFeedsProgressFinished = finished
        updateFeedsProgressTotal = total
        didUpdateFeedsArgs.append((finished, total))
    }


    var updatedFeeds: [Feed]? = nil
    func didUpdateFeeds(feeds: [Feed]) {
        updatedFeeds = feeds
    }
}
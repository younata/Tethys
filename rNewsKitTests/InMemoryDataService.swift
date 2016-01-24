@testable import rNewsKit

class InMemoryDataService: DataService {

    let searchIndex: SearchIndex? = FakeSearchIndex()

    var feeds = [Feed]()
    var articles = [Article]()
    var enclosures = [Enclosure]()

    func createFeed(callback: (Feed) -> (Void)) {
        let feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        callback(feed)
        self.feeds.append(feed)
    }

    func createArticle(feed: Feed?, callback: (Article) -> (Void)) {
        let article = Article(title: "", link: nil, summary: "", author: "", published: NSDate(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0, feed: feed, flags: [], enclosures: [])
        feed?.addArticle(article)
        callback(article)
        self.articles.append(article)
    }

    func createEnclosure(article: Article?, callback: (Enclosure) -> (Void)) {
        let enclosure = Enclosure(url: NSURL(), kind: "", article: article)
        article?.addEnclosure(enclosure)
        callback(enclosure)
        self.enclosures.append(enclosure)
    }

    func feedsMatchingPredicate(predicate: NSPredicate, callback: [Feed] -> Void) {
        callback(self.feeds.filter({ predicate.evaluateWithObject($0) }))
    }

    func articlesMatchingPredicate(predicate: NSPredicate, callback: [Article] -> Void) {
        callback(self.articles.filter({ predicate.evaluateWithObject($0) }))
    }

    func enclosuresMatchingPredicate(predicate: NSPredicate, callback: [Enclosure] -> Void) {
        callback(self.enclosures.filter({ predicate.evaluateWithObject($0) }))
    }

    func saveFeed(feed: Feed, callback: (Void) -> (Void)) {
        callback()
    }

    func saveArticle(article: Article, callback: (Void) -> (Void)) {
        callback()
    }

    func saveEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        callback()
    }

    func deleteFeed(feed: Feed, callback: (Void) -> (Void)) {
        if let index = self.feeds.indexOf(feed) {
            self.feeds.removeAtIndex(index)
        }
        for article in feed.articlesArray {
            feed.removeArticle(article)
        }
        callback()
    }

    func deleteArticle(article: Article, callback: (Void) -> (Void)) {
        if let index = self.articles.indexOf(article) {
            self.articles.removeAtIndex(index)
        }
        article.feed?.removeArticle(article)
        article.feed = nil
        for enclosure in article.enclosuresArray {
            article.removeEnclosure(enclosure)
        }
        callback()
    }

    func deleteEnclosure(enclosure: Enclosure, callback: (Void) -> (Void)) {
        if let index = self.enclosures.indexOf(enclosure) {
            self.enclosures.removeAtIndex(index)
        }
        enclosure.article?.removeEnclosure(enclosure)
        enclosure.article = nil
        callback()
    }
}
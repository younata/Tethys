import Foundation
import Ra
import CoreData
import JavaScriptCore
import Muon
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
    import UIKit
#elseif os(OSX)
    import Cocoa
#endif

public protocol DataRetriever {
    func allTags(callback: ([String]) -> (Void))
    func feeds(callback: ([Feed]) -> (Void))
    func feedsMatchingTag(tag: String?, callback: ([Feed]) -> (Void))
    func articlesOfFeeds(feeds: [Feed], matchingSearchQuery: String, callback: ([Article]) -> (Void))
    func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void))
}

public protocol DataSubscriber: NSObjectProtocol {
    func markedArticle(article: Article, asRead read: Bool)

    func deletedArticle(article: Article)

    func willUpdateFeeds()
    func didUpdateFeedsProgress(finished: Int, total: Int)
    func didUpdateFeeds(feeds: [Feed])
}

public protocol DataWriter {
    func addSubscriber(subscriber: DataSubscriber)

    func newFeed(callback: (Feed) -> (Void))
    func saveFeed(feed: Feed)
    func deleteFeed(feed: Feed)
    func markFeedAsRead(feed: Feed)

    func saveArticle(article: Article)
    func deleteArticle(article: Article)
    func markArticle(article: Article, asRead: Bool)

    func updateFeeds(callback: ([Feed], [NSError]) -> (Void))

    func updateFeed(feed: Feed, callback: (Feed?, NSError?) -> (Void))
}

internal class DataRepository: DataRetriever, DataWriter {
    private let objectContext: NSManagedObjectContext
    private let mainQueue: NSOperationQueue
    private let backgroundQueue: NSOperationQueue
    private let urlSession: NSURLSession

    private let searchIndex: SearchIndex?

    internal init(objectContext: NSManagedObjectContext, mainQueue: NSOperationQueue, backgroundQueue: NSOperationQueue,
                  urlSession: NSURLSession, searchIndex: SearchIndex?) {
        self.objectContext = objectContext
        self.mainQueue = mainQueue
        self.backgroundQueue = backgroundQueue
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
        self.allFeedsOnBackgroundQueue { feeds in
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


    internal func articlesOfFeeds(feeds: [Feed], matchingSearchQuery query: String, callback: ([Article]) -> (Void)) {
        self.backgroundQueue.addOperationWithBlock {
            let articles = feeds.reduce(Array<Article>()) { return $0 + $1.articles }
            let matchingArticlesSet = Set(articles.filter({ return self.article($0, matchesQuery: query) }))
            let returnValue = Array(matchingArticlesSet)
            self.mainQueue.addOperationWithBlock {
                callback(returnValue)
            }
        }
    }

    internal func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        self.allFeedsOnBackgroundQueue { feeds in
            let queriedArticles = self.privateArticlesMatchingQuery(query, feeds: feeds)
            self.mainQueue.addOperationWithBlock {
                callback(queriedArticles)
            }
        }
    }

    // MARK: Private (DataRetriever)

    private func article(article: Article, matchesQuery query: String) -> Bool {
        if article.title.containsString(query) {
            return true
        }
        if article.summary.containsString(query) {
            return true
        }
        if article.description.containsString(query) {
            return true
        }
        if article.summary.containsString(query) {
            return true
        }
        if article.author.containsString(query) {
            return true
        }
        if article.content.containsString(query) {
            return true
        }
        if article.link?.absoluteString.containsString(query) == true {
            return true
        }
        return false
    }

    private func allFeedsOnBackgroundQueue(callback: ([Feed] -> (Void))) {
        self.backgroundQueue.addOperationWithBlock {
            callback(self.synchronousAllFeeds())
        }
    }

    private func synchronousAllFeeds() -> [Feed] {
        let feeds = DataUtility.feedsWithPredicate(NSPredicate(value: true),
            managedObjectContext: self.objectContext).sort {
                return $0.displayTitle < $1.displayTitle
        }
        let nonQueryFeeds = feeds.reduce(Array<Feed>()) {
            if $1.isQueryFeed {
                return $0
            } else {
                return $0 + [$1]
            }
        }
        let queryFeeds = feeds.reduce(Array<Feed>()) {
            if $1.isQueryFeed {
                return $0 + [$1]
            } else {
                return $0
            }
        }
        for feed in queryFeeds {
            let articles = self.privateArticlesMatchingQuery(feed.query!, feeds: nonQueryFeeds)
            for article in articles {
                feed.addArticle(article)
            }
        }
        return feeds
    }

    private func privateArticlesMatchingQuery(query: String, feeds: [Feed]) -> [Article] {
        let nonQueryFeeds = feeds.reduce(Array<Feed>()) {
            if $1.isQueryFeed {
                return $0
            } else {
                return $0 + [$1]
            }
        }
        let articles = nonQueryFeeds.reduce(Array<Article>()) {articles, feed in
            return articles + feed.articles
        }
        let context = JSContext()
        context.exceptionHandler = { context, exception in
            print("JS Error: \(exception)")
        }
        let script = "var query = \(query)\n" +
            "var include = function(articles) {\n" +
            "  var ret = [];\n" +
            "  for (var i = 0; i < articles.length; i++) {\n" +
            "    var article = articles[i];\n" +
            "    if (query(article)) { ret.push(article) }\n" +
            "  }\n" +
            "  return ret\n" +
        "}"
        context.evaluateScript(script)
        let include = context.objectForKeyedSubscript("include")
        let res = include.callWithArguments([articles]).toArray()
        return res as? [Article] ?? []
    }

    // MARK: DataWriter

    private let subscribers = NSHashTable.weakObjectsHashTable()

    internal func addSubscriber(subscriber: DataSubscriber) {
        subscribers.addObject(subscriber)
    }

    internal func newFeed(callback: (Feed) -> (Void)) {
        self.backgroundQueue.addOperationWithBlock {
            let feed = self.synchronousNewFeed()
            self.mainQueue.addOperationWithBlock {
                callback(feed)
            }
        }
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
            if let cdfeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feedID), managedObjectContext: self.objectContext, sortDescriptors: []).first as? CoreDataFeed {
                let articleIDsToDelete = cdfeed.articles.map {
                    return $0.objectID.URIRepresentation().absoluteString
                }
                self.objectContext.performBlockAndWait {
                    for article in cdfeed.articles {
                        self.objectContext.deleteObject(article)
                    }
                    self.objectContext.deleteObject(cdfeed)
                }
                if #available(iOS 9.0, *) {
                    self.searchIndex?.deleteIdentifierFromIndex(articleIDsToDelete) {_ in }
                }
                self.save()
            }
        }
    }

    internal func markFeedAsRead(feed: Feed) {
        self.backgroundQueue.addOperationWithBlock {
            for article in feed.articles where article.read == false {
                self.privateMarkArticle(article, asRead: true)
            }
        }
    }

    internal func saveArticle(article: Article) {
        guard let feedID = article.feed?.feedID where article.updated else {
            return
        }
        self.backgroundQueue.addOperationWithBlock {
            if let cdfeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feedID), managedObjectContext: self.objectContext, sortDescriptors: []).first as? CoreDataFeed {
                self.saveArticle(article, feed: cdfeed)
            }
        }
    }

    internal func deleteArticle(article: Article) {
        guard let articleID = article.articleID else {
            return
        }
        self.backgroundQueue.addOperationWithBlock {
            if let cdarticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", articleID), managedObjectContext: self.objectContext, sortDescriptors: []).first as? CoreDataArticle {
                let identifier = cdarticle.objectID.URIRepresentation().absoluteString
                self.objectContext.performBlockAndWait {
                    self.objectContext.deleteObject(cdarticle)
                }
                if #available(iOS 9.0, *) {
                    self.searchIndex?.deleteIdentifierFromIndex([identifier]) {error in
                    }
                }
                self.mainQueue.addOperationWithBlock {
                    for object in self.subscribers.allObjects {
                        if let subscriber = object as? DataSubscriber {
                            subscriber.deletedArticle(article)
                        }
                    }
                }
                self.save()
            }
        }
    }

    internal func markArticle(article: Article, asRead: Bool) {
        self.backgroundQueue.addOperationWithBlock {
            self.privateMarkArticle(article, asRead: asRead)
        }
    }

    private var updatingFeedsCallbacks = Array<([Feed], [NSError]) -> (Void)>()
    internal func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        self.updatingFeedsCallbacks.append(callback)
        if self.updatingFeedsCallbacks.count != 1 {
            return
        }

        self.allFeedsOnBackgroundQueue {feeds in
            if feeds.isEmpty {
                self.mainQueue.addOperationWithBlock {
                    for updateCallback in self.updatingFeedsCallbacks {
                        updateCallback([], [])
                    }
                    self.updatingFeedsCallbacks = []
                }
                return
            }
            self.privateUpdateFeeds(feeds) {updatedFeeds, errors in
                self.mainQueue.addOperationWithBlock {
                    for updateCallback in self.updatingFeedsCallbacks {
                        updateCallback(updatedFeeds, errors)
                    }
                    for object in self.subscribers.allObjects {
                        if let subscriber = object as? DataSubscriber {
                            subscriber.didUpdateFeeds(updatedFeeds)
                        }
                    }
                    self.updatingFeedsCallbacks = []
                }
            }
        }
    }

    internal func updateFeed(feed: Feed, callback: (Feed?, NSError?) -> (Void)) {
        self.backgroundQueue.addOperationWithBlock {
            self.privateUpdateFeeds([feed]) {feeds, errors in
                self.mainQueue.addOperationWithBlock {
                    for object in self.subscribers.allObjects {
                        if let subscriber = object as? DataSubscriber {
                            subscriber.didUpdateFeeds(feeds)
                        }
                    }
                    callback(feeds.first, errors.first)
                }
            }
        }
    }

    //MARK: Private (DataWriter)

    internal func synchronousNewFeed() -> Feed {
        let entityDescription = NSEntityDescription.entityForName("Feed", inManagedObjectContext: self.objectContext)!
        var cdfeed: CoreDataFeed? = nil
        self.objectContext.performBlockAndWait {
            cdfeed = CoreDataFeed(entity: entityDescription, insertIntoManagedObjectContext: self.objectContext)
            do { try self.objectContext.save() } catch { }
        }
        return Feed(feed: cdfeed!)
    }

    private func upsertArticle(muonArticle: Muon.Article, feed: Feed) -> Article? {
        let predicate = NSPredicate(format: "link = %@ && title == %@ && feed == %@", muonArticle.link?.absoluteString ?? "", muonArticle.title ?? "", feed.feedID!)
        if let article = DataUtility.entities("Article", matchingPredicate: predicate,
            managedObjectContext: self.objectContext, sortDescriptors: []).last as? CoreDataArticle {
                if article.updatedAt != muonArticle.updated {
                    DataUtility.updateArticle(article, item: muonArticle)
                    self.save()
                }
                return nil
        } else {
            // create
            let article = NSEntityDescription.insertNewObjectForEntityForName("Article",
                inManagedObjectContext: self.objectContext) as! CoreDataArticle
            DataUtility.updateArticle(article, item: muonArticle)
            self.save()
            return Article(article: article, feed: nil)
        }
    }

    private func save() {
        self.objectContext.performBlockAndWait {
            do {
                try self.objectContext.save()
            } catch {}
        }
    }

    private func synchronousSaveFeed(feed: Feed) {
        // Do not call this on the main thread
        guard let feedID = feed.feedID where feed.updated else {
            return
        }
        if let cdfeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feedID), managedObjectContext: self.objectContext, sortDescriptors: []).first as? CoreDataFeed {
            cdfeed.title = feed.title
            cdfeed.url = feed.url?.absoluteString
            cdfeed.summary = feed.summary
            cdfeed.query = feed.query
            cdfeed.tags = feed.tags
            cdfeed.waitPeriodInt = feed.waitPeriod
            cdfeed.remainingWaitInt = feed.remainingWait
            cdfeed.image = feed.image

            for article in feed.articles where !feed.isQueryFeed {
                self.saveArticle(article, feed: cdfeed)
            }
            self.save()
        }
    }

    private func saveArticle(article: Article, feed: CoreDataFeed) {
        guard let articleID = article.articleID where article.updated else {
            return
        }
        if let cdarticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", articleID), managedObjectContext: self.objectContext, sortDescriptors: []).first as? CoreDataArticle {
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

            #if os(iOS)
                if #available(iOS 9.0, *) {
                    let identifier = cdarticle.objectID.URIRepresentation().absoluteString

                    let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeHTML as String)
                    attributes.title = article.title
                    if let articleSummaryData = (article.summary as NSString).dataUsingEncoding(NSUTF8StringEncoding) {
                        do {
                            let summary = try NSAttributedString(data: articleSummaryData, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType], documentAttributes: nil)
                            attributes.contentDescription = summary.string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                        } catch {}
                    }
                    let feedTitleWords = article.feed?.title.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                    attributes.keywords = ["article"] + (feedTitleWords ?? [])
                    attributes.URL = article.link
                    attributes.timestamp = article.updatedAt ?? article.published
                    attributes.authorNames = [article.author]

                    if let image = article.feed?.image, let data = UIImagePNGRepresentation(image) {
                        attributes.thumbnailData = data
                    }

                    let item = CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: nil, attributeSet: attributes)
                    item.expirationDate = NSDate.distantFuture()
                    self.searchIndex?.addItemsToIndex([item]) {_ in }
                }
            #endif
            self.save()
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
            }.resume()
        }
    }

    private func privateMarkArticle(article: Article, asRead read: Bool) {
        guard let articleID = article.articleID else {
            return
        }
        article.read = read
        if let cdarticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", articleID), managedObjectContext: self.objectContext, sortDescriptors: []).first as? CoreDataArticle {
            cdarticle.read = read
            save()
        }
        self.mainQueue.addOperationWithBlock {
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    subscriber.markedArticle(article, asRead: read)
                }
            }
        }
    }

    private func privateUpdateFeeds(feeds: [Feed], callback: ([Feed], [NSError]) -> (Void)) {
        var feedsLeft = feeds.count
        guard feedsLeft != 0 else {
            callback([], [])
            return
        }
        self.mainQueue.addOperationWithBlock {
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    subscriber.willUpdateFeeds()
                }
            }
        }

        var updatedFeeds: [Feed] = []
        var errors: [NSError] = []

        var totalProgress = feedsLeft * 2
        var currentProgress = 0

        let loadFeed = {(url: NSURL, callback: (Muon.Feed?, NSError?) -> (Void)) -> (Void) in
            let dataTask = self.urlSession.dataTaskWithURL(url) {data, response, error in
                currentProgress++
                self.mainQueue.addOperationWithBlock {
                    for object in self.subscribers.allObjects {
                        if let subscriber = object as? DataSubscriber {
                            subscriber.didUpdateFeedsProgress(currentProgress, total: totalProgress)
                        }
                    }
                }
                if let error = error {
                    callback(nil, error)
                } else if let data = data, string = NSString(data: data, encoding: NSUTF8StringEncoding) as? String {
                    let feedParser = Muon.FeedParser(string: string)
                    feedParser.success { callback($0, nil) }.failure { callback(nil, $0) }
                    self.backgroundQueue.addOperation(feedParser)
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
            dataTask.resume()
        }
        for feed in feeds {
            guard let url = feed.url where feed.remainingWait == 0 else {
                feed.remainingWait--
                self.synchronousSaveFeed(feed)
                feedsLeft--
                totalProgress -= 2
                if (feedsLeft == 0) {
                    callback(updatedFeeds, errors)
                }
                continue
            }
            loadFeed(url) {muonFeed, error in
                if let err = error {
                    if err.domain == "com.rachelbrindle.rssclient.server" {
                        feed.remainingWait++
                        self.synchronousSaveFeed(feed)
                    }
                    var userInfo = err.userInfo
                    userInfo["feedTitle"] = feed.title
                    let modifiedError = NSError(domain: err.domain, code: err.code, userInfo: userInfo)
                    errors.append(modifiedError)
                } else if let item = muonFeed {
                    self.updateFeed(feed, muonFeed: item)
                    self.updateFeedImage(feed, muonFeed: item)

                    for muonArticle in item.articles {
                        if let article = self.upsertArticle(muonArticle, feed: feed) {
                            feed.addArticle(article)
                            article.feed = feed
                        }
                    }

                    self.synchronousSaveFeed(feed)

                    updatedFeeds.append(feed)
                }

                currentProgress++
                self.mainQueue.addOperationWithBlock {
                    for object in self.subscribers.allObjects {
                        if let subscriber = object as? DataSubscriber {
                            subscriber.didUpdateFeedsProgress(currentProgress, total: totalProgress)
                        }
                    }
                }

                feedsLeft--
                if (feedsLeft == 0) {
                    callback(self.synchronousAllFeeds(), errors)
                }
            }
        }
    }
}
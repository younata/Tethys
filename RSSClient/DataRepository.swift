import Foundation
import Ra
import CoreData
import JavaScriptCore
import Muon
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
    import UIKit
    import Reachability
#elseif os(OSX)
    import Cocoa
#endif

public protocol DataRetriever {
    func allTags(callback: ([String]) -> (Void))
    func feeds(callback: ([Feed]) -> (Void))
    func feedsMatchingTag(tag: String?, callback: ([Feed]) -> (Void))
    func articlesOfFeeds(feeds: [Feed], matchingSearchQuery: String, callback: (CoreDataBackedArray<Article>) -> (Void))
    func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void))
}

public protocol DataSubscriber: NSObjectProtocol {
    func markedArticles(articles: [Article], asRead read: Bool)

    func deletedArticle(article: Article)

    func deletedFeed(feed: Feed, feedsLeft: Int)

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

internal protocol Reachable {
    var hasNetworkConnectivity: Bool { get }
}

#if os(iOS)
    extension Reachability: Reachable {
        var hasNetworkConnectivity: Bool {
            return self.currentReachabilityStatus != .NotReachable
        }
    }
#endif

// swiftlint:disable file_length
// swiftlint:disable type_body_length
// swiftlint:disable function_body_length

internal class DataRepository: DataRetriever, DataWriter {
    private let objectContext: NSManagedObjectContext
    private let mainQueue: NSOperationQueue
    private let backgroundQueue: NSOperationQueue
    private let urlSession: NSURLSession

    private let searchIndex: SearchIndex?

    private let reachable: Reachable?

    private let dataUtility: DataUtilityType

    internal init(objectContext: NSManagedObjectContext, mainQueue: NSOperationQueue, backgroundQueue: NSOperationQueue,
        urlSession: NSURLSession, searchIndex: SearchIndex?, reachable: Reachable?, dataUtility: DataUtilityType) {
            self.objectContext = objectContext
            self.mainQueue = mainQueue
            self.backgroundQueue = backgroundQueue
            self.urlSession = urlSession
            self.searchIndex = searchIndex
            self.reachable = reachable
            self.dataUtility = dataUtility
    }

    //MARK: - DataRetriever

    internal func allTags(callback: ([String]) -> (Void)) {
        self.dataUtility.feedsWithPredicate(NSPredicate(format: "tags != nil"),
            managedObjectContext: self.objectContext) {feedsWithTags in

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
        self.allFeeds { feeds in
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


    internal func articlesOfFeeds(feeds: [Feed],
        matchingSearchQuery query: String,
        callback: (CoreDataBackedArray<Article>) -> (Void)) {
            let feeds = feeds.filter({return !$0.isQueryFeed})
            guard !feeds.isEmpty else {
                self.mainQueue.addOperationWithBlock { callback(CoreDataBackedArray()) }
                return
            }
            self.backgroundQueue.addOperationWithBlock {
                var articles = feeds[0].articlesArray
                for feed in feeds[1..<feeds.count] {
                    articles = articles.combine(feed.articlesArray)
                }
                let titlePredicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
                let summaryPredicate = NSPredicate(format: "summary CONTAINS[cd] %@", query)
                let descriptionPredicate = NSPredicate(format: "summary CONTAINS[cd] %@", query)
                let authorPredicate = NSPredicate(format: "author CONTAINS[cd] %@", query)
                let contentPredicate = NSPredicate(format: "content CONTAINS[cd] %@", query)
                let linkPredicate = NSPredicate(format: "link CONTAINS[cd] %@", query)

                let predicates = [
                    titlePredicate,
                    summaryPredicate,
                    descriptionPredicate,
                    authorPredicate,
                    contentPredicate,
                    linkPredicate
                ]
                let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                let returnValue = articles.filterWithPredicate(compoundPredicate)
                self.mainQueue.addOperationWithBlock {
                    callback(returnValue)
                }
            }
    }

    internal func articlesMatchingQuery(query: String, callback: ([Article]) -> (Void)) {
        self.allFeeds { feeds in
            let queriedArticles = self.privateArticlesMatchingQuery(query, feeds: feeds)
            self.mainQueue.addOperationWithBlock {
                callback(queriedArticles)
            }
        }
    }

    // MARK: Private (DataRetriever)

    private func allFeeds(callback: ([Feed] -> (Void))) {
        let truePredicate = NSPredicate(value: true)
        self.dataUtility.feedsWithPredicate(truePredicate, managedObjectContext: self.objectContext) {unsorted in
            let feeds = unsorted.sort { return $0.displayTitle < $1.displayTitle }

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
            feeds.forEach {
                let _ = $0.articlesArray.count
                let _ = $0.articlesArray[0]
            }
            callback(feeds)
        }
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
            return articles + feed.articlesArray
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
        self.synchronousSaveFeed(feed)
    }

    internal func deleteFeed(feed: Feed) {
        guard let feedID = feed.feedID else {
            return
        }
        self.dataUtility.entities("Feed",
            matchingPredicate: NSPredicate(format: "self = %@", feedID),
            managedObjectContext: self.objectContext) {managedObjects in
                guard let cdfeed = managedObjects.first as? CoreDataFeed else { return }

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

                self.allFeeds { feeds in
                    let feedsLeft = feeds.count

                    for object in self.subscribers.allObjects {
                        if let subscriber = object as? DataSubscriber {
                            self.mainQueue.addOperationWithBlock {
                                subscriber.deletedFeed(feed, feedsLeft: feedsLeft)
                            }
                        }
                    }
                }
        }
    }

    internal func markFeedAsRead(feed: Feed) {
        let articles = feed.articlesArray.filterWithPredicate(NSPredicate(format: "read != 1"))
        self.privateMarkArticles(Array(articles), asRead: true)
    }

    internal func saveArticle(article: Article) {
        guard let feedID = article.feed?.feedID where article.updated else {
            return
        }
        self.dataUtility.entities("Feed",
            matchingPredicate: NSPredicate(format: "self = %@", feedID),
            managedObjectContext: self.objectContext) {managedObjects in
                guard let cdFeed = managedObjects.first as? CoreDataFeed else { return }
                self.saveArticle(article, feed: cdFeed)
        }
    }

    internal func deleteArticle(article: Article) {
        guard let articleID = article.articleID else {
            return
        }
        self.dataUtility.entities("Article",
            matchingPredicate: NSPredicate(format: "self = %@", articleID),
            managedObjectContext: self.objectContext) {managedObjects in
                guard let cdarticle = managedObjects.first as? CoreDataArticle else { return }
                let identifier = cdarticle.objectID.URIRepresentation().absoluteString
                self.objectContext.performBlockAndWait {
                    cdarticle.feed = nil
                    self.objectContext.deleteObject(cdarticle)
                }
                if #available(iOS 9.0, *) {
                    self.searchIndex?.deleteIdentifierFromIndex([identifier]) {error in
                    }
                }
                for object in self.subscribers.allObjects {
                    if let subscriber = object as? DataSubscriber {
                        self.mainQueue.addOperationWithBlock {
                            subscriber.deletedArticle(article)
                        }
                    }
                }
                self.save()
        }
    }

    internal func markArticle(article: Article, asRead: Bool) {
        self.privateMarkArticles([article], asRead: asRead)
    }

    private var updatingFeedsCallbacks = Array<([Feed], [NSError]) -> (Void)>()
    internal func updateFeeds(callback: ([Feed], [NSError]) -> (Void)) {
        self.updatingFeedsCallbacks.append(callback)
        if self.updatingFeedsCallbacks.count != 1 {
            return
        }

        self.allFeeds {feeds in
            guard feeds.isEmpty == false && self.reachable?.hasNetworkConnectivity == true else {
                self.mainQueue.addOperationWithBlock {
                    for updateCallback in self.updatingFeedsCallbacks {
                        updateCallback([], [])
                    }
                    self.updatingFeedsCallbacks = []
                }
                return
            }

            self.privateUpdateFeeds(feeds) {updatedFeeds, errors in
                for updateCallback in self.updatingFeedsCallbacks {
                    self.mainQueue.addOperationWithBlock {
                        updateCallback(updatedFeeds, errors)
                    }
                }
                for object in self.subscribers.allObjects {
                    if let subscriber = object as? DataSubscriber {
                        self.mainQueue.addOperationWithBlock {
                            subscriber.didUpdateFeeds(updatedFeeds)
                        }
                    }
                }
                self.updatingFeedsCallbacks = []
            }
        }
    }

    internal func updateFeed(feed: Feed, callback: (Feed?, NSError?) -> (Void)) {
        guard self.reachable?.hasNetworkConnectivity == true else {
            callback(feed, nil)
            return
        }
        self.privateUpdateFeeds([feed]) {feeds, errors in
            for object in self.subscribers.allObjects {
                if let subscriber = object as? DataSubscriber {
                    self.mainQueue.addOperationWithBlock {
                        subscriber.didUpdateFeeds(feeds)
                    }
                }
                callback(feeds.first, errors.first)
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
        var existingArticle: Article? = nil
        for article in feed.articlesArray {
            if let articleLink = article.link, let muonLink = muonArticle.link where articleLink == muonLink {
                existingArticle = article
                break
            }
            if let muonArticleID = muonArticle.guid where muonArticleID == article.identifier {
                existingArticle = article
                break
            } else {
                let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
                let articleTitle = article.title.stringByTrimmingCharactersInSet(characterSet)
                let muonArticleTitle = muonArticle.title?.stringByTrimmingCharactersInSet(characterSet)
                if articleTitle == muonArticleTitle {
                    existingArticle = article
                    break
                }
            }
        }
        if let articleID = existingArticle?.articleID {
            self.dataUtility.entities("Article",
                matchingPredicate: NSPredicate(format: "self = %@", articleID),
                managedObjectContext: self.objectContext) {managedObjects in
                    guard let article = managedObjects.first as? CoreDataArticle else { return }
                    if article.updatedAt != muonArticle.updated {
                        self.dataUtility.updateArticle(article, item: muonArticle)
                        self.save()
                    }
            }
            return nil
        } else {
            // create
            let article = NSEntityDescription.insertNewObjectForEntityForName("Article",
                inManagedObjectContext: self.objectContext) as! CoreDataArticle
            self.dataUtility.updateArticle(article, item: muonArticle)
            self.save()
            return Article(article: article, feed: nil)
        }
    }

    private func save() {
        self.objectContext.performBlockAndWait {
            let _ = try? self.objectContext.save()
        }
    }

    private func synchronousSaveFeed(feed: Feed) {
        guard let feedID = feed.feedID where feed.updated else {
            return
        }
        self.dataUtility.entities("Feed",
            matchingPredicate: NSPredicate(format: "self = %@", feedID),
            managedObjectContext: self.objectContext) {managedObjects in
                guard let cdfeed = managedObjects.first as? CoreDataFeed else { return }
                cdfeed.title = feed.title
                cdfeed.url = feed.url?.absoluteString
                cdfeed.summary = feed.summary
                cdfeed.query = feed.query
                cdfeed.tags = feed.tags
                cdfeed.waitPeriodInt = feed.waitPeriod
                cdfeed.remainingWaitInt = feed.remainingWait
                cdfeed.image = feed.image

                for article in feed.articlesArray where !feed.isQueryFeed {
                    self.saveArticle(article, feed: cdfeed)
                }
                self.save()
        }
    }

    private func saveArticle(article: Article, feed: CoreDataFeed) {
        guard let articleID = article.articleID where article.updated else {
            return
        }
        self.dataUtility.entities("Article",
            matchingPredicate: NSPredicate(format: "self = %@", articleID),
            managedObjectContext: self.objectContext) {managedObjects in
                guard let cdarticle = managedObjects.first as? CoreDataArticle else { return }
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
                        let characterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
                        if let articleSummaryData = article.summary.dataUsingEncoding(NSUTF8StringEncoding) {
                            do {
                                let summary = try NSAttributedString(data: articleSummaryData,
                                    options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType],
                                    documentAttributes: nil)
                                let trimmedSummary = summary.string.stringByTrimmingCharactersInSet(characterSet)
                                attributes.contentDescription = trimmedSummary
                            } catch {}
                        }
                        let feedTitleWords = article.feed?.title.componentsSeparatedByCharactersInSet(characterSet)
                        attributes.keywords = ["article"] + (feedTitleWords ?? [])
                        attributes.URL = article.link
                        attributes.timestamp = article.updatedAt ?? article.published
                        attributes.authorNames = [article.author]

                        if let image = article.feed?.image, let data = UIImagePNGRepresentation(image) {
                            attributes.thumbnailData = data
                        }

                        let item = CSSearchableItem(uniqueIdentifier: identifier,
                            domainIdentifier: nil,
                            attributeSet: attributes)
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

    private func privateMarkArticles(articles: [Article], asRead read: Bool) {
        guard articles.count > 0 else {
            return
        }

        let articleIds = articles.reduce([NSManagedObjectID]()) {
            if let id = $1.articleID {
                return $0 + [id]
            }
            return $0
        }
        articles.forEach { $0.read = read }

        self.dataUtility.entities("Article",
            matchingPredicate: NSPredicate(format: "self IN %@", articleIds),
            managedObjectContext: self.objectContext) {managedObjects in
                guard let cdArticles = managedObjects as? [CoreDataArticle] else { return }
                cdArticles.forEach {
                    $0.read = read
                }
                self.save()
                for object in self.subscribers.allObjects {
                    if let subscriber = object as? DataSubscriber {
                        self.mainQueue.addOperationWithBlock {
                            subscriber.markedArticles(articles, asRead: read)
                        }
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

        for object in self.subscribers.allObjects {
            if let subscriber = object as? DataSubscriber {
                self.mainQueue.addOperationWithBlock {
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
                for object in self.subscribers.allObjects {
                    if let subscriber = object as? DataSubscriber {
                        self.mainQueue.addOperationWithBlock {
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
                        error = NSError(domain: "com.rachelbrindle.rssclient.server",
                            code: response.statusCode,
                            userInfo: [
                                NSLocalizedFailureReasonErrorKey:
                                    NSHTTPURLResponse.localizedStringForStatusCode(response.statusCode)
                            ])
                    } else {
                        error = NSError(domain: "com.rachelbrindle.rssclient.unknown",
                            code: 1,
                            userInfo: [NSLocalizedFailureReasonErrorKey: "Unknown"])
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
                if feedsLeft == 0 {
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
                for object in self.subscribers.allObjects {
                    if let subscriber = object as? DataSubscriber {
                        self.mainQueue.addOperationWithBlock {
                            subscriber.didUpdateFeedsProgress(currentProgress, total: totalProgress)
                        }
                    }
                }

                feedsLeft--
                if feedsLeft == 0 {
                    self.allFeeds {
                        callback($0, errors)
                    }
                }
            }
        }
    }
}

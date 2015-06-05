import Foundation
import CoreData
import WebKit
import JavaScriptCore
import Alamofire
import Muon

public class DataManager: NSObject {

    // MARK: OPML

    public func importOPML(opml: NSURL, progress: (Double) -> Void, completion: ([Feed]) -> Void) {
        if let text = NSString(contentsOfURL: opml, encoding: NSUTF8StringEncoding, error: nil) {
            let opmlParser = OPMLParser(text: text as String)
            opmlParser.failure {(error) in
                completion([])
            }
            opmlParser.callback = {(items) in
                var ret: [Feed] = []
                if items.count == 0 {
                    completion([])
                }
                var i = 0
                for item in items {
                    self.mainQueue.addOperationWithBlock {
                        if item.isQueryFeed() {
                            if let query = item.query {
                                var newFeed = self.newQueryFeed(item.title!, code: query, summary: item.summary)
                                for tag in (item.tags ?? []) {
                                    newFeed.addTag(tag)
                                }
                                ret.append(newFeed)
                            }
                            i++
                            progress(Double(i) / Double(items.count))
                            if i == items.count {
                                completion(ret)
                            }
                        } else {
//                            if let feed = item.xmlURL,
//                            var newFeed = self.newFeed(feed, completion: {error in
//                                if let err = error {
//                                    println("error importing \(feed): \(err)")
//                                }
//                                println("imported \(feed)")
//                                i++
//                                progress(Double(i) / Double(items.count))
//                                if i == items.count {
//                                    completion(ret)
//                                }
//                            }) {
//                                for tag in (item.tags ?? []) {
//                                    newFeed.addTag(tag)
//                                }
//                                ret.append(newFeed)
//                            } else {
//                                i++
//                                progress(Double(i) / Double(items.count))
//                                if i == items.count {
//                                    completion(ret)
//                                }
//                            }
                        }
                    }
                }
            }
            backgroundQueue.addOperation(opmlParser)
        }
    }

    // MARK: CoreDataFeeds

    public func allTags() -> [String] {
        let feedsWithTags = DataUtility.feedsWithPredicate(NSPredicate(format: "tags != nil"),
            managedObjectContext: self.backgroundObjectContext)

        let setOfTags = feedsWithTags.reduce(Set<String>()) {set, feed in
            return set.union(Set(feed.tags))
        }

        return Array(setOfTags).sorted { return $0.lowercaseString < $1.lowercaseString }
    }

    public func feeds() -> [Feed] {
        return DataUtility.feedsWithPredicate(NSPredicate(value: true),
            managedObjectContext: self.backgroundObjectContext).sorted {
                return $0.title < $1.title
        }
    }

    public func feedsMatchingTag(tag: String?) -> [Feed] {
        if let theTag = (tag == "" ? nil : tag) {
            return feeds().filter {
                let tags = $0.tags
                for t in tags {
                    if t.rangeOfString(theTag) != nil {
                        return true
                    }
                }
                return false
            }
        } else {
            return feeds()
        }
    }

    public func newFeed(feedURL: String, completion: (NSError?) -> (Void)) -> Feed {
        let predicate = NSPredicate(format: "url = %@", feedURL)
        let feed: Feed
        if let theFeed = DataUtility.entities("Feed", matchingPredicate: predicate,
            managedObjectContext: self.backgroundObjectContext).last as? CoreDataFeed {
                feed = Feed(feed: theFeed)
        } else {
            let cdfeed = newFeed()
            cdfeed.url = feedURL
            feed = Feed(feed: cdfeed)
            self.backgroundObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: cdfeed)
        }
        #if os(iOS)
            let app = UIApplication.sharedApplication()
            app.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        #endif
        self.updateFeeds([feed], completion: completion)
//        self.writeOPML()
        return feed
    }

    public func newQueryFeed(title: String, code: String, summary: String? = nil) -> Feed {
        let predicate = NSPredicate(format: "title = %@", title)
        var feed: CoreDataFeed! = nil
        if let theFeed = DataUtility.entities("Feed", matchingPredicate: predicate,
            managedObjectContext: self.backgroundObjectContext).last as? CoreDataFeed {
                feed = theFeed
        } else {
            feed = newFeed()
            feed.title = title
            feed.query = code
            feed.summary = summary
            self.backgroundObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        return Feed(feed: feed)
    }

    func newFeed() -> CoreDataFeed {
        return NSEntityDescription.insertNewObjectForEntityForName("Feed",
            inManagedObjectContext: backgroundObjectContext) as! CoreDataFeed
    }

    public func saveFeed(feed: Feed) {
        // TODO: this.
    }

    public func deleteFeed(feed: Feed) {
        // TODO: yeah.
    }

    public func markFeedAsRead(feed: Feed) {
        // TODO: this
    }

    func deleteFeed(feed: CoreDataFeed) {
        for article in feed.articles {
            if let article = article as? CoreDataArticle {
                self.backgroundObjectContext.deleteObject(article)
            }
        }
        self.backgroundObjectContext.deleteObject(feed)
        self.backgroundObjectContext.save(nil)
        if (feeds().count == 0) {
            #if os(iOS)
                let app = UIApplication.sharedApplication()
                app.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
            #endif
        }
//        self.writeOPML()
    }

    public func updateFeeds(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion)
    }

    public func updateFeedsInBackground(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion, backgroundFetch: true)
    }

    var stats : [(parseTime: Double, importTime: Double)] = []

    func finishedUpdatingFeed(error: NSError?, var feed: Feed,
        managedObjectContext: NSManagedObjectContext, inout feedsLeft: Int,
        completion: (NSError?) -> (Void)) {
            feedsLeft--
            if error != nil {
                println("Errored loading: \(error)")
            }
            if (error == nil) {
                if feed.waitPeriod == nil || feed.waitPeriod != 0 {
                    feed.waitPeriod = 0
                    feed.remainingWait = 0
//                    feed.managedObjectContext?.save(nil)
                }
            } else if let err = error where (err.domain == NSURLErrorDomain && err.code > 0) {
                feed.waitPeriod = (feed.waitPeriod ?? 0) + 1
                feed.remainingWait = feed.waitPeriodInRefreshes()
//                feed.managedObjectContext?.save(nil)
            }
            if feedsLeft == 0 {
                if backgroundObjectContext.hasChanges {
                    backgroundObjectContext.save(nil)
                }
                mainQueue.addOperationWithBlock {
                    completion(error)
                    self.setApplicationBadgeCount()
                }
            }
    }

    let mainManager: Manager = {
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.timeoutIntervalForRequest = 30.0
        return Alamofire.Manager(configuration: config)
    }()
    lazy var backgroundManager: Manager = {
        let ident = "com.rachelbrindle.rNews.background"
        let config = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(ident)
        config.timeoutIntervalForRequest = 30.0
        return Manager(configuration: config)
    }()

    public func updateFeeds(feeds: [Feed], backgroundFetch: Bool = false, completion: (NSError?)->(Void) = {_ in }) {
        let feedIds = feeds.filter { !$0.isQueryFeed && $0.feedID != nil }.map { $0.feedID! }

        if feedIds.count == 0 {
            completion(nil);
            return;
        }

        backgroundQueue.addOperationWithBlock {
            let ctx = self.backgroundObjectContext
            let theFeeds = DataUtility.feedsWithPredicate(NSPredicate(format: "self in %@", feedIds),
                managedObjectContext: ctx)
            var feedsLeft = theFeeds.count

            self.stats = []

            for feed in theFeeds {
                let manager = backgroundFetch ? self.backgroundManager : self.mainManager
                let wait = feed.remainingWait ?? 0
                if wait != 0 {
//                    feed.remainingWait = wait - 1
//                    ctx.save(nil)
                    println("Skipping feed at \(feed.url)")
                    feedsLeft--
                    if (feedsLeft == 0) {
                        completion(nil)
                        return
                    }
                    continue
                }

                FeedRepository.loadFeed(feed.url!.absoluteString!, downloadManager: manager,
                    operationQueue: self.backgroundQueue) {muonFeed, error in
                        if let err = error {
                            self.finishedUpdatingFeed(error, feed: feed, managedObjectContext: ctx,
                                feedsLeft: &feedsLeft, completion: completion)
                        } else if let info = muonFeed {
                            // DataUtility.updateFeed(feed, info: info)
                            // DataUtility.updateFeedImage(feed, info: info, manager: manager)
                            for item in info.articles {
                                if var article = self.upsertArticle(item, context: ctx) {
                                    // feed.addArticle(article)
                                    // article.feed = feed
                                }
                            }
                            self.finishedUpdatingFeed(nil, feed: feed, managedObjectContext: ctx,
                                feedsLeft: &feedsLeft, completion: completion)
                        }
                }
            }
        }
    }

    func estimateNextFeedTime(feed: Feed) -> (NSDate?, Double) { // Time, stddev
        // This could be much better done.
        // For example, some feeds only update on weekdays, which this would tell it to update
        // once every 7/5ths of a day, instead of once a day for 5 days, then not at all on the weekends.
        // But for now, it's ok.
        let times: [NSTimeInterval] = feed.articles.map {
            return $0.published.timeIntervalSince1970
        }.sorted { return $0 < $1 }

        if times.count < 2 {
            return (nil, 0)
        }

        func mean(values: [Double]) -> Double {
            return (values.reduce(0.0) { return $0 + $1 }) / Double(values.count)
        }

        var intervals: [NSTimeInterval] = []
        for (i, t) in enumerate(times) {
            if i == (times.count - 1) {
                break
            }
            intervals.append(fabs(times[i+1] - t))
        }
        let averageTimeInterval = mean(intervals)

        func stdev(values: [Double], average: Double) -> Double {
            return sqrt(mean(values.map { pow($0 - average, 2) }))
        }

        let standardDeviation = stdev(intervals, averageTimeInterval)

        let d = NSDate(timeIntervalSince1970: times.last! + averageTimeInterval)
        let end = d.dateByAddingTimeInterval(standardDeviation)

        if NSDate().compare(end) == NSComparisonResult.OrderedDescending {
            return (nil, 0)
        }

        return (NSDate(timeIntervalSince1970: times.last! + averageTimeInterval), standardDeviation)
    }

    func setApplicationBadgeCount() {
        let num = feeds().filter {
            return !$0.isQueryFeed
        }.reduce(0) {
            return $0 + $1.unreadArticles().count
        }
        #if os(iOS)
            UIApplication.sharedApplication().applicationIconBadgeNumber = num
        #elseif os(OSX)
            NSApplication.sharedApplication().dockTile.badgeLabel = "\(num)"
        #endif
    }

    // MARK: CoreDataEnclosures

    func allEnclosures() -> [CoreDataEnclosure] {
        let dataEnclosures = DataUtility.entities("Enclosure",
            matchingPredicate: NSPredicate(value: true),
            managedObjectContext: self.backgroundObjectContext) as? [CoreDataEnclosure] ?? []

        return dataEnclosures.sorted {a, b in
            if let da = a.url, let db = b.url {
                return da.lastPathComponent < db.lastPathComponent
            }
            return true
        }
    }

    func allEnlosures(downloaded: Bool) -> [CoreDataEnclosure] {
        return allEnclosures().filter { $0.downloaded?.boolValue == downloaded }
    }

    func deleteEnclosure(enclosure: CoreDataEnclosure) {
        enclosure.article?.removeEnclosuresObject(enclosure)
        enclosure.article = nil
        self.backgroundObjectContext.deleteObject(enclosure)
    }

    private var enclosureProgress: [NSObject: Double] = [:]

    var enclosureDownloadProgress: Double {
        get {
            let n = Array(enclosureProgress.values).reduce(0.0) {return $0 + $1}
            return n / Double(enclosureProgress.count)
        }
    }

    func progressForEnclosure(enclosure: CoreDataEnclosure) -> Double {
        if let progress = self.enclosureProgress[enclosure.objectID] {
            return progress
        }
        return -1
    }

    func updateEnclosure(enclosure: CoreDataEnclosure, progress: Double) {
        self.enclosureProgress[enclosure.objectID] = progress
    }

    func downloadEnclosure(enclosure: CoreDataEnclosure, progress: (Double) -> (Void) = {(_) in },
        completion: (CoreDataEnclosure, NSError?) -> (Void) = {(_) in }) {
            let downloaded = enclosure.downloaded?.boolValue ?? false
            if let url = enclosure.url where !downloaded {
                mainManager.request(.GET, url).response {(_, _, response, error) in
                    if let err = error {
                        completion(enclosure, err)
                    } else if let response = response as? NSData {
                        enclosure.data = response
                        completion(enclosure, nil)
                    } else {
                        completion(enclosure, nil)
                    }
                    self.enclosureProgress.removeValueForKey(enclosure.objectID)
                    }.progress {(_, bytesRead, totalBytes) in
                        let p = Double(bytesRead) / Double(totalBytes)
                        self.updateEnclosure(enclosure, progress: p)
                        progress(p)
                }
            } else {
                completion(enclosure, nil)
            }
    }

    // MARK: Articles

    func upsertArticle(item: Muon.Article, var context ctx: NSManagedObjectContext! = nil) -> Article? {
        let predicate = NSPredicate(format: "link = %@", item.link ?? "")
        if let article = DataUtility.entities("Article", matchingPredicate: predicate,
            managedObjectContext: ctx).last as? CoreDataArticle {
                if article.updatedAt != item.updated {
                    DataUtility.updateArticle(article, item: item)

                    for enc in item.enclosures {
                        DataUtility.insertEnclosureFromItem(enc, article: article)
                    }
                }
                return nil
        } else {
            // create
            let article = NSEntityDescription.insertNewObjectForEntityForName("Article",
                inManagedObjectContext: ctx) as! CoreDataArticle
            DataUtility.updateArticle(article, item: item)

            for enclosure in item.enclosures {
                DataUtility.insertEnclosureFromItem(enclosure, article: article)
            }
            return Article(article: article, feed: nil)
        }
    }

    func readArticle(article: CoreDataArticle, read: Bool = true) {
        article.read = read
        article.managedObjectContext?.save(nil)
        setApplicationBadgeCount()
    }

    func readArticles(articles: [CoreDataArticle], read: Bool = true) {
        for article in articles {
            article.read = read
        }
        articles.first?.managedObjectContext?.save(nil)
        setApplicationBadgeCount()
    }

    func newArticle() -> CoreDataArticle {
        return NSEntityDescription.insertNewObjectForEntityForName("Article",
            inManagedObjectContext: self.backgroundObjectContext) as! CoreDataArticle
    }

    private var theArticles: [CoreDataArticle]? = nil

    private func refreshArticles() {
        let coreDataObjects = DataUtility.entities("Article",
            matchingPredicate: NSPredicate(value: true),
            managedObjectContext: self.backgroundObjectContext)
        theArticles = (coreDataObjects as? [CoreDataArticle] ?? []).sorted {a, b in
            if let da = a.updatedAt ?? a.published, let db = b.updatedAt ?? b.published {
                return da.timeIntervalSince1970 > db.timeIntervalSince1970
            }
            return true
        }
    }

    func articles() -> [CoreDataArticle] {
        if let articles = theArticles {
            return articles
        } else {
            refreshArticles()
            return articles()
        }
    }

    private var queryFeedResults: [Feed: [Article]]? = nil
    private var reloading = false

    public func articlesMatchingQuery(query: String, feed: Feed? = nil) -> [Article] {
        if let f = feed {
            if let res = self.queryFeedResults {
                if let results = res[f] {
                    return results
                } else {
                    self.queryFeedResults![f] = []
                    if !reloading {
                        reloadQFR()
                    }
                }
            } else {
                queryFeedResults = [f: []]
                reloadQFR()
            }
        } else {
            let results = articlesFromQuery(query, articles: articles())
            if let f = feed {
                if queryFeedResults == nil {
                    queryFeedResults = [:]
                }
                queryFeedResults![f] = results
            }
            return results
        }
        return []
    }

    private func articlesFromQuery(query: String, articles: [CoreDataArticle],
        context: JSContext? = nil) -> [Article] {
//        let ctx = context ?? setUpContext(JSContext()!)
//        let script = "include = \(query)"
//        ctx.evaluateScript(script)
//        let function = ctx.objectForKeyedSubscript("include")
//
//        let results = articles.filter {(article) in
//            let val = function.callWithArguments([article.asDict()])
//            return val.toBool()
//        }
//        return results
        return []
    }

    // MARK: Scripting

    private func setUpContext(ctx: JSContext) -> JSContext {
        ctx.exceptionHandler = {(context, value) in
            println("Javascript exception: \(value)")
        }
        ctx.evaluateScript("var console = {}")
        let console = ctx.objectForKeyedSubscript("console")
        var block : @objc_block (NSString) -> Void = {(message: NSString) in println("\(message)")}
        console.setObject(unsafeBitCast(block, AnyObject.self), forKeyedSubscript: "log")
        let script = "var include = function(article) { return true }"
        ctx.evaluateScript(script)
        return ctx
    }

    private func console(ctx: JSContext) {
        ctx.evaluateScript("var console = {}")
        let console = ctx.objectForKeyedSubscript("console")
        var block : @objc_block (NSString) -> Void = {(message: NSString) in println("\(message)")}
        console.setObject(unsafeBitCast(block, AnyObject.self), forKeyedSubscript: "log")
    }

    // MARK: Background Data Fetch

    func managedObjectContextDidSave() {
        theArticles = nil
        reloadQFR()
    }

    func reloadQFR() {
        backgroundQueue.cancelAllOperations()
        if let qfr = queryFeedResults {
            reloading = true
            var feeds: [NSManagedObjectID] = []
            for feed in self.feeds() {
                if let objectID = feed.feedID where feed.query != nil {
                    feeds.append(objectID)
                }
            }
            backgroundQueue.addOperationWithBlock {
                self.updateBackgroundThreads(feeds)
            }
        }
    }

    func updateBackgroundThreads(feeds: [NSManagedObjectID]) {
        let articles = DataUtility.entities("Article", matchingPredicate: NSPredicate(value: true),
            managedObjectContext: backgroundObjectContext) as? [CoreDataArticle] ?? []
        var articleIDs: [NSManagedObjectID: [NSManagedObjectID]] = [:]
        for feed in feeds {
            let feedPredicate = NSPredicate(format: "self == %@", feed)
            let theFeed = DataUtility.entities("Feed", matchingPredicate: feedPredicate,
                managedObjectContext: backgroundObjectContext).last as? CoreDataFeed
            if let query = theFeed?.query {
                let res = articlesFromQuery(query, articles: articles, context: self.backgroundContext)
                let array: [NSManagedObjectID] = []
//                articleIDs[feed] = res.filter(array) { list, article in
//                    if let objectID = article.objectID {
//                        return list + [objectID]
//                    }
//                    return list
//                }
            }
        }
        mainQueue.addOperationWithBlock {
            var queryFeedResults: [Feed: [Article]] = [:]
            for (key, value) in articleIDs {
                let feedPredicate = NSPredicate(format: "self == %@", (key as NSManagedObjectID))
                let theFeed = DataUtility.feedsWithPredicate(feedPredicate,
                    managedObjectContext: self.backgroundObjectContext).last

                let articlePredicate = NSPredicate(format: "self IN %@", value)
                let articles = DataUtility.articlesWithPredicate(articlePredicate,
                    managedObjectContext: self.backgroundObjectContext)

                if let feed = theFeed {
                    queryFeedResults[feed] = articles
                }
            }
            self.queryFeedResults = queryFeedResults
            self.reloading = false
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: nil)
        }
    }

    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = NSBundle(forClass: self.classForCoder).URLForResource("RSSClient", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let storeURL = NSURL.fileURLWithPath(documentsDirectory().stringByAppendingPathComponent("RSSClient.sqlite"))
        let persistentStore = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        var error: NSError? = nil
        var options: [String: AnyObject] = [NSMigratePersistentStoresAutomaticallyOption: true,
                                            NSInferMappingModelAutomaticallyOption: true]
        persistentStore.addPersistentStoreWithType(NSSQLiteStoreType,
            configuration: self.managedObjectModel.configurations.last as? String,
            URL: storeURL, options: options, error: &error)
        if (error != nil) {
            NSFileManager.defaultManager().removeItemAtURL(storeURL!, error: nil)
            error = nil
            persistentStore.addPersistentStoreWithType(NSSQLiteStoreType,
                configuration: self.managedObjectModel.configurations.last as? String,
                URL: storeURL, options: options, error: &error)
            if let err = error {
                println("Fatal error adding persistent data store: \(err)")
                fatalError("")
            }
        }
        return persistentStore
    }()
    public lazy var backgroundObjectContext: NSManagedObjectContext = {
        let ctx = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        ctx.persistentStoreCoordinator = self.persistentStoreCoordinator
        return ctx
    }()

    lazy var mainQueue: NSOperationQueue = {
        return self.injector!.create(kMainQueue) as! NSOperationQueue
    }()

    lazy var backgroundQueue: NSOperationQueue = {
        let queue = self.injector!.create(kBackgroundQueue) as! NSOperationQueue
        queue.addOperationWithBlock {
            self.backgroundContext
        }
        return queue
    }()

    lazy var backgroundJSVM: JSVirtualMachine? = JSVirtualMachine()

    lazy var backgroundContext: JSContext? = {
        return self.setUpContext(JSContext(virtualMachine: self.backgroundJSVM))
    }()

    func configure() {
        managedObjectContextDidSave() // update all the query feeds.
    }

    public override init() {
        super.init()
//        NSNotificationCenter.defaultCenter().addObserver(self,
//            selector: "managedObjectContextDidSave",
//            name: NSManagedObjectContextDidSaveNotification,
//            object: backgroundObjectContext)
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
import Foundation
import CoreData
import WebKit
import JavaScriptCore
import Alamofire
import Muon

class DataManager: NSObject {

    // MARK: OPML

    func importOPML(opml: NSURL) {
        importOPML(opml, progress: {(_) in }, completion: {(_) in })
    }

    func importOPML(opml: NSURL, progress: (Double) -> Void, completion: ([CoreDataFeed]) -> Void) {
        if let text = NSString(contentsOfURL: opml, encoding: NSUTF8StringEncoding, error: nil) {
            let opmlParser = OPMLParser(text: text as String)
            opmlParser.failure {(error) in
                completion([])
            }
            opmlParser.callback = {(items) in
                var ret : [CoreDataFeed] = []
                if items.count == 0 {
                    completion([])
                }
                var i = 0
                for item in items {
                    dispatch_async(dispatch_get_main_queue()) {
                        if item.isQueryFeed() {
                            if let query = item.query {
                                let newFeed = self.newQueryFeed(item.title!, code: query, summary: item.summary)
                                newFeed.tags = item.tags
                                ret.append(newFeed)
                            }
                            i++
                            progress(Double(i) / Double(items.count))
                            if i == items.count {
                                completion(ret)
                            }
                        } else {
                            if let feed = item.xmlURL {
                                let newFeed = self.newFeed(feed) {(error) in
                                    if let err = error {
                                        println("error importing \(feed): \(err)")
                                    }
                                    println("imported \(feed)")
                                    i++
                                    progress(Double(i) / Double(items.count))
                                    if i == items.count {
                                        completion(ret)
                                    }
                                }
                                newFeed.tags = item.tags
                                ret.append(newFeed)
                            } else {
                                i++
                                progress(Double(i) / Double(items.count))
                                if i == items.count {
                                    completion(ret)
                                }
                            }
                        }
                    }
                }
            }
            opmlParser.parse()
        }
    }

    func generateOPMLContents(feeds: [CoreDataFeed]) -> String {
        func sanitize(str: String?) -> String {
            if str == nil {
                return ""
            }
            var s = str!
            s = s.stringByReplacingOccurrencesOfString("\"", withString: "&quot;")
            s = s.stringByReplacingOccurrencesOfString("'", withString: "&apos;")
            s = s.stringByReplacingOccurrencesOfString("<", withString: "&gt;")
            s = s.stringByReplacingOccurrencesOfString(">", withString: "&lt;")
            s = s.stringByReplacingOccurrencesOfString("&", withString: "&amp;")
            return s
        }

        var ret = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n<opml version=\"2.0\">\n    <body>\n"
        for feed in feeds.filter({return $0.query == nil}) {
            if feed.url == nil {
                ret += "        <outline query=\"\(sanitize(feed.query))\" title=\"\(sanitize(feed.title))\" summary=\"\(sanitize(feed.summary))\" type=\"query\""
            } else {
                ret += "        <outline xmlURL=\"\(sanitize(feed.url))\" title=\"\(sanitize(feed.title))\" type=\"rss\""
            }
            if feed.tags != nil {
                let tags : String = ",".join(feed.tags as! [String])
                ret += " tags=\"\(tags)\""
            }
            ret += "/>\n"
        }
        ret += "</body>\n</opml>"
        return ret
    }

    func writeOPML() {
        self.generateOPMLContents(self.feeds()).writeToFile(NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent("rnews.opml"), atomically: true, encoding: NSUTF8StringEncoding, error: nil)
    }

    // MARK: CoreDataFeeds

    func allTags(managedObjectContext: NSManagedObjectContext? = nil) -> [String] {
        let feedsWithTags = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "tags != nil"), managedObjectContext: (managedObjectContext ?? self.managedObjectContext)) as? [CoreDataFeed] ?? []

        let setOfTags = feedsWithTags.reduce(NSSet()) {(set, feed) in
            return set.setByAddingObjectsFromArray(feed.allTags())
        }

        return (setOfTags.allObjects as? [String] ?? []).sorted { return $0.lowercaseString < $1.lowercaseString }
    }

    func feeds(managedObjectContext: NSManagedObjectContext? = nil) -> [CoreDataFeed] {
        return (DataUtility.entities("Feed", matchingPredicate: NSPredicate(value: true), managedObjectContext: (managedObjectContext ?? self.managedObjectContext)) as? [CoreDataFeed] ?? []).sorted {
            if $0.title == nil {
                return true
            } else if $1.title == nil {
                return false
            }
            return $0.title < $1.title
        } ?? []
    }

    func feedsMatchingTag(tag: String?, managedObjectContext: NSManagedObjectContext? = nil, allowIncompleteTags: Bool = true) -> [CoreDataFeed] {
        if let theTag = (tag == "" ? nil : tag) {
            return feeds(managedObjectContext: managedObjectContext).filter {
                let tags = $0.allTags()
                for t in tags {
                    if allowIncompleteTags {
                        if t.rangeOfString(theTag) != nil {
                            return true
                        }
                    } else {
                        if t == theTag {
                            return true
                        }
                    }
                }
                return false
            }
        } else {
            return feeds(managedObjectContext: managedObjectContext)
        }
    }

    func newFeed(feedURL: String) -> CoreDataFeed {
        return newFeed(feedURL, completion: {(_) in })
    }

    func newFeed(feedURL: String, completion: (NSError?) -> (Void)) -> CoreDataFeed {
        let predicate = NSPredicate(format: "url = %@", feedURL)
        var feed: CoreDataFeed! = nil
        if let theFeed = DataUtility.entities("Feed", matchingPredicate: predicate, managedObjectContext: self.managedObjectContext).last as? CoreDataFeed {
            feed = theFeed
        } else {
            feed = newFeed()
            feed.url = feedURL
            self.managedObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        #if os(iOS)
            UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        #endif
        self.updateFeeds([feed], completion: completion)
        self.writeOPML()
        return feed
    }

    func newQueryFeed(title: String, code: String, summary: String? = nil) -> CoreDataFeed {
        let predicate = NSPredicate(format: "title = %@", title)
        var feed: CoreDataFeed! = nil
        if let theFeed = DataUtility.entities("Feed", matchingPredicate: predicate, managedObjectContext: self.managedObjectContext).last as? CoreDataFeed {
            feed = theFeed
        } else {
            feed = newFeed()
            feed.title = title
            feed.query = code
            feed.summary = summary
            self.managedObjectContext.save(nil)
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: feed)
        }
        return feed
    }

    func newFeed() -> CoreDataFeed {
        return NSEntityDescription.insertNewObjectForEntityForName("Feed", inManagedObjectContext: managedObjectContext) as! CoreDataFeed
    }

    func deleteFeed(feed: CoreDataFeed) {
        for article in feed.allArticles() {
            self.managedObjectContext.deleteObject(article)
        }
        self.managedObjectContext.deleteObject(feed)
        self.managedObjectContext.save(nil)
        if (feeds().count == 0) {
            #if os(iOS)
                UIApplication.sharedApplication().setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
            #endif
        }
        self.writeOPML()
    }

    func updateFeeds(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion)
    }

    func updateFeedsInBackground(completion: (NSError?)->(Void)) {
        updateFeeds(feeds(), completion: completion, backgroundFetch: true)
    }

    var parsers : [FeedParser] = []
    var stats : [(parseTime: Double, importTime: Double)] = []

    func finishedUpdatingFeed(feedParser: FeedParser?, error: NSError?, feed: CoreDataFeed, managedObjectContext: NSManagedObjectContext, inout feedsLeft: Int, completion: (NSError?) -> (Void)) {
        feedsLeft--
        if error != nil {
            println("Errored loading: \(error)")
        }
        if (feedParser != nil && error == nil) {
            if feed.waitPeriod == nil || feed.waitPeriod.integerValue != 0 {
                feed.waitPeriod = NSNumber(integer: 0)
                feed.remainingWait = NSNumber(integer: 0)
                feed.managedObjectContext?.save(nil)
            }
        } else if let err = error {
            if (err.domain == NSURLErrorDomain && err.code > 0) { // FIXME: check the error code for specific HTTP error codes.
                feed.waitPeriod = NSNumber(integer: (feed.waitPeriod?.integerValue ?? 0) + 1)
                feed.remainingWait = feed.waitPeriodInRefreshes(feed.waitPeriod.integerValue)
                println("Setting feed at \(feed.url) to have remainingWait of \(feed.remainingWait) refreshes")
                feed.managedObjectContext?.save(nil)
            }
        }
        if let fp = feedParser {
            self.parsers = self.parsers.filter { $0 != fp }
        }
        if feedsLeft == 0 {
            assert(self.parsers.count == 0)
            if managedObjectContext.hasChanges {
                managedObjectContext.save(nil)
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(error)
                self.setApplicationBadgeCount()
            }
            let parseTime = stats.reduce(0.0) {
                return $0 + $1.parseTime
            }
            let importTime = stats.reduce(0.0) {
                return $0 + $1.importTime
            }
            let total = parseTime + importTime
            println("\n\n")
            println("Parsing feed took \(parseTime / total * 100)% of the time")
            println("Importing data took \(importTime / total * 100)% of the time")
            println("\n\n")
        }
    }

    let mainManager = Alamofire.Manager(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    let backgroundManager = Alamofire.Manager(configuration: NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier("com.rachelbrindle.rNews.background"))

    func updateFeeds(feeds: [CoreDataFeed], backgroundFetch: Bool = false, completion: (NSError?)->(Void) = {_ in }) {
        let feedIds = feeds.filter { $0.url != nil }.map { $0.objectID }

        if feedIds.count == 0 {
            completion(nil);
            return;
        }

        let queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
        dispatch_async(queue) {
            let ctx = self.backgroundObjectContext
            let theFeeds = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self in %@", feedIds), managedObjectContext: ctx) as? [CoreDataFeed] ?? []
            var feedsLeft = theFeeds.count

            self.stats = []

            for feed in theFeeds {
                let feedParser = FeedParser(string: "")//URL: NSURL(string: feed.url)!)

                let manager = backgroundFetch ? self.backgroundManager : self.mainManager // FIXME: using backgroundManager seems to always fail?
                let wait = feed.remainingWait?.integerValue ?? 0
                if wait != 0 {
                    feed.remainingWait = NSNumber(integer: wait - 1)
                    feed.managedObjectContext?.save(nil)
                    println("Skipping feed at \(feed.url)")
                    feedsLeft--
                    if (feedsLeft == 0) {
                        completion(nil)
                        return
                    }
                    continue
                }

                manager.request(.GET, feed.url).responseString {(req, response, str, error) in
                    if let err = error {
                        self.finishedUpdatingFeed(nil, error: error, feed: feed, managedObjectContext: ctx, feedsLeft: &feedsLeft, completion: completion)
                    } else if let s = str {
                        let start = CACurrentMediaTime()
                        let feedParser = FeedParser(string: s).success {info in
                            let mid = CACurrentMediaTime()

                            DataUtility.updateFeed(feed, info: info)
                            DataUtility.updateFeedImage(feed, info: info, manager: manager)
                            for item in info.articles {
                                let article = self.upsertArticle(item, context: ctx)
                                feed.addArticlesObject(article)
                                article.feed = feed
                            }

                            let importTime = CACurrentMediaTime() - mid
                            let parseTime = mid - start
                            let toInsert : (parseTime: Double, importTime: Double) = (parseTime, importTime)
                            self.stats.append(toInsert)
                            self.finishedUpdatingFeed(feedParser, error: nil, feed: feed, managedObjectContext: ctx, feedsLeft: &feedsLeft, completion: completion)
                        }
                        feedParser.onFailure = {(error) in
                            self.finishedUpdatingFeed(feedParser, error: error, feed: feed, managedObjectContext: ctx, feedsLeft: &feedsLeft, completion: completion)
                        }
                        feedParser.main()
                        self.parsers.append(feedParser)
                    } else {
                        // str and error are nil.
                        println("Errored loading \(feed.url) with unknown error")
                        self.parsers = self.parsers.filter { $0 != feedParser }
                    }
                }
            }
        }
    }

    func estimateNextFeedTime(feed: CoreDataFeed) -> (NSDate?, Double) { // Time, stddev
        // This could be much better done.
        // For example, some feeds only update on weekdays, which this would tell it to update
        // once every 7/5ths of a day, instead of once a day for 5 days, then not at all on the weekends.
        // But for now, it's ok.
        let times : [NSTimeInterval] = feed.allArticles(self).map {
            return $0.published.timeIntervalSince1970
            }.sorted { return $0 < $1 }

        if times.count < 2 {
            return (nil, 0)
        }

        func mean(values: [Double]) -> Double {
            return (values.reduce(0.0) { return $0 + $1 }) / Double(values.count)
        }

        var intervals : [NSTimeInterval] = []
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
        let num = feeds(managedObjectContext: managedObjectContext).filter {return !$0.isQueryFeed()}.reduce(0) {return $0 + Int($1.unreadArticles(self))}
        #if os(iOS)
            UIApplication.sharedApplication().applicationIconBadgeNumber = num
        #elseif os(OSX)
            NSApplication.sharedApplication().dockTile.badgeLabel = "\(num)"
        #endif
    }

    // MARK: CoreDataEnclosures

    func allEnclosures() -> [CoreDataEnclosure] {
        return (DataUtility.entities("Enclosure", matchingPredicate: NSPredicate(value: true), managedObjectContext: self.managedObjectContext) as? [CoreDataEnclosure] ?? []).sorted {(a : CoreDataEnclosure, b: CoreDataEnclosure) in
            if let da = a.url, let db = b.url {
                return da.lastPathComponent < db.lastPathComponent
            }
            return true
        }
    }

    func allEnlosures(downloaded: Bool) -> [CoreDataEnclosure] {
        return (DataUtility.entities("Enclosure", matchingPredicate: NSPredicate(format: "downloaded = %d", downloaded), managedObjectContext: self.managedObjectContext) as? [CoreDataEnclosure] ?? []).sorted {(a : CoreDataEnclosure, b: CoreDataEnclosure) in
            if let da = a.url, let db = b.url {
                return da.lastPathComponent < db.lastPathComponent
            }
            return true
        }
    }

    func deleteEnclosure(enclosure: CoreDataEnclosure) {
        enclosure.article.removeEnclosuresObject(enclosure)
        enclosure.article = nil
        self.managedObjectContext.deleteObject(enclosure)
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

    func downloadEnclosure(enclosure: CoreDataEnclosure, progress: (Double) -> (Void) = {(_) in }, completion: (CoreDataEnclosure, NSError?) -> (Void) = {(_) in }) {
        let downloaded = (enclosure.downloaded == nil ? false : enclosure.downloaded.boolValue)
        if (!downloaded) {
            mainManager.request(.GET, enclosure.url).response {(_, _, response, error) in
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

    func upsertArticle(item: Muon.Article, var context ctx: NSManagedObjectContext! = nil) -> CoreDataArticle {
        let predicate = NSPredicate(format: "link = %@", item.link ?? "")
        if let article = DataUtility.entities("Article", matchingPredicate: predicate, managedObjectContext: ctx).last as? CoreDataArticle {
            if article.updatedAt != item.updated {
                DataUtility.updateArticle(article, item: item)

                for enc in item.enclosures {
                    DataUtility.insertEnclosureFromItem(enc, article: article)
                }
            }
            return article
        } else {
            // create
            let article = NSEntityDescription.insertNewObjectForEntityForName("Article", inManagedObjectContext: ctx) as! CoreDataArticle
            DataUtility.updateArticle(article, item: item)

            for enclosure in item.enclosures {
                DataUtility.insertEnclosureFromItem(enclosure, article: article)
            }
            return article
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
        return NSEntityDescription.insertNewObjectForEntityForName("Article", inManagedObjectContext: self.managedObjectContext) as! CoreDataArticle
    }

    private var theArticles : [CoreDataArticle]? = nil

    private func refreshArticles() {
        theArticles = (DataUtility.entities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: self.managedObjectContext) as? [CoreDataArticle] ?? []).sorted {(a : CoreDataArticle, b: CoreDataArticle) in
            if let da = a.updatedAt ?? a.published, let db = b.updatedAt ?? b.published {
                return da.timeIntervalSince1970 > db.timeIntervalSince1970
            }
            return true
        }
    }

    func articles() -> [CoreDataArticle] {
        if theArticles == nil {
            refreshArticles()
        }
        return theArticles!
    }

    private var queryFeedResults : [CoreDataFeed: [CoreDataArticle]]? = nil
    private var reloading = false

    func articlesMatchingQuery(query: String, feed: CoreDataFeed? = nil) -> [CoreDataArticle] {
        if let f = feed {
            if let res = queryFeedResults {
                if let results = res[f] {
                    return results
                } else {
                    queryFeedResults![f] = []
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

    private func articlesFromQuery(query: String, articles: [CoreDataArticle], context: JSContext? = nil) -> [CoreDataArticle] {
        let ctx = context ?? setUpContext(JSContext()!)
        let script = "include = \(query)"
        ctx.evaluateScript(script)
        let function = ctx.objectForKeyedSubscript("include")

        let results = articles.filter {(article) in
            let val = function.callWithArguments([article.asDict()])
            return val.toBool()
        }
        return results
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

    private func fetching(ctx: JSContext, isBackground: Bool) {
        let moc = isBackground ? self.backgroundObjectContext : self.managedObjectContext

        ctx.evaluateScript("var data = {onNewFeed: [], onNewArticle: []}")
        let data = ctx.objectForKeyedSubscript("data")

        var articles : @objc_block (Void) -> [NSDictionary] = {
            return (DataUtility.entities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: moc) as? [CoreDataArticle] ?? []).map {return $0.asDict()}
        }
        data.setObject(unsafeBitCast(articles, AnyObject.self), forKeyedSubscript: "articles")

        var queryArticles : @objc_block (NSString, [NSObject]) -> [NSDictionary] = {(query, args) in
            let predicate = NSPredicate(format: query as String, argumentArray: args)
            return (DataUtility.entities("Article", matchingPredicate: predicate, managedObjectContext: moc) as? [CoreDataArticle] ?? []).map {$0.asDict()}
        }
        data.setObject(unsafeBitCast(queryArticles, AnyObject.self), forKeyedSubscript: "articlesMatchingQuery")

        var feeds : @objc_block (Void) -> [NSDictionary] = {
            return (DataUtility.entities("Feed", matchingPredicate: NSPredicate(value: true), managedObjectContext: moc) as? [CoreDataFeed] ?? []).map {return $0.asDict()}
        }
        data.setObject(unsafeBitCast(feeds, AnyObject.self), forKeyedSubscript: "feeds")

        var queryFeeds : @objc_block (NSString, [NSObject]) -> [NSDictionary] = {(query, args) in // queries for feeds, not to be confused with query feeds.
            let predicate = NSPredicate(format: query as String, argumentArray: args)
            return (DataUtility.entities("Feed", matchingPredicate: predicate, managedObjectContext: moc) as? [CoreDataFeed] ?? []).map {$0.asDict()}
        }
        data.setObject(unsafeBitCast(queryFeeds, AnyObject.self), forKeyedSubscript: "feedsMatchingQuery")

        var addOnNewFeed : @objc_block (@objc_block (NSDictionary) -> Void) -> Void = {(block) in
            var onNewFeed = data.objectForKeyedSubscript("onNewFeed").toArray()
            onNewFeed.append(unsafeBitCast(block, AnyObject.self))
            data.setObject(onNewFeed, forKeyedSubscript: "onNewFeed")
        }
        data.setObject(unsafeBitCast(addOnNewFeed, AnyObject.self), forKeyedSubscript: "onNewFeed")
    }

    // MARK: Background Data Fetch

    func managedObjectContextDidSave() {
        theArticles = nil
        reloadQFR()
    }

    func reloadQFR() {
        operationQueue.cancelAllOperations()
        if let qfr = queryFeedResults {
            reloading = true
            var feeds : [NSManagedObjectID] = []
            for feed in self.feeds() {
                if feed.query != nil {
                    feeds.append(feed.objectID)
                }
            }
            operationQueue.addOperation(NSBlockOperation(block: {
                self.updateBackgroundThreads(feeds)
            }))
        }
    }

    func updateBackgroundThreads(feeds: [NSManagedObjectID]) {
        let articles = DataUtility.entities("Article", matchingPredicate: NSPredicate(value: true), managedObjectContext: backgroundObjectContext) as? [CoreDataArticle] ?? []
        var articleIDs : [NSManagedObjectID: [NSManagedObjectID]] = [:]
        for feed in feeds {
            let theFeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self == %@", feed), managedObjectContext: backgroundObjectContext).last as? CoreDataFeed
            if let query = theFeed?.query {
                let res = articlesFromQuery(query, articles: articles, context: self.backgroundContext)
                articleIDs[feed] = res.map { return $0.objectID }
            }
        }
        dispatch_async(dispatch_get_main_queue()) {
            var queryFeedResults : [CoreDataFeed: [CoreDataArticle]] = [:]
            for (key, value) in articleIDs {
                let theFeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self == %@", (key as NSManagedObjectID)), managedObjectContext: self.managedObjectContext).last as! CoreDataFeed
                let articles = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self IN %@", value), managedObjectContext: self.managedObjectContext) as? [CoreDataArticle] ?? []
                queryFeedResults[theFeed] = articles
            }
            self.queryFeedResults = queryFeedResults
            self.reloading = false
            NSNotificationCenter.defaultCenter().postNotificationName("UpdatedFeed", object: nil)
        }
    }

    let managedObjectModel: NSManagedObjectModel
    let persistentStoreCoordinator: NSPersistentStoreCoordinator
    let managedObjectContext: NSManagedObjectContext

    let operationQueue = NSOperationQueue()
    let backgroundObjectContext: NSManagedObjectContext
    var backgroundJSVM: JSVirtualMachine? = nil
    var backgroundContext: JSContext? = nil

    override init() {
        var unitTesting = false
        if let modelURL = NSBundle.mainBundle().URLForResource("RSSClient", withExtension: "momd") {
            managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL)!
        } else {
            managedObjectModel = NSManagedObjectModel.mergedModelFromBundles(NSBundle.allBundles())!
            unitTesting = true
        }
        let applicationDocumentsDirectory: String = (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).last as! String)
        let storeURL = NSURL.fileURLWithPath(applicationDocumentsDirectory.stringByAppendingPathComponent("RSSClient.sqlite"))
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        var error: NSError? = nil
        var options : [String: AnyObject] = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        if unitTesting {
            persistentStoreCoordinator.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil, error: &error)
        } else {
            persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: managedObjectModel.configurations.last as? String, URL: storeURL, options: options, error: &error)
        }
        if (error != nil) {
            NSFileManager.defaultManager().removeItemAtURL(storeURL!, error: nil)
            error = nil
            persistentStoreCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: managedObjectModel.configurations.last as? String, URL: storeURL, options: options, error: &error)
            if (error != nil) {
                println("Fatal error adding persistent data store: \(error!)")
                fatalError("")
            }
        }

        for manager in [mainManager, backgroundManager] {
            manager.session.configuration.timeoutIntervalForRequest = 30.0;
            manager.session.configuration.timeoutIntervalForResource = 30.0;
        }

        managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator

        self.backgroundObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        self.backgroundObjectContext.parentContext = managedObjectContext

        super.init()
        operationQueue.underlyingQueue = dispatch_queue_create("DataManager Background Queue", nil)
        operationQueue.addOperation(NSBlockOperation(block: {
            self.backgroundJSVM = JSVirtualMachine()
            self.backgroundContext = self.setUpContext(JSContext(virtualMachine: self.backgroundJSVM))
        }))
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "managedObjectContextDidSave", name: NSManagedObjectContextDidSaveNotification, object: managedObjectContext)
        managedObjectContextDidSave() // update all the query feeds.
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
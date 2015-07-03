import Quick
import Nimble
@testable import rNewsKit
import Ra
import CoreSpotlight
#if os(iOS)
    import MobileCoreServices
#endif

class FeedRepositorySpec: QuickSpec {
    override func spec() {
        var subject: DataRepository! = nil

        var mainQueue: FakeOperationQueue! = nil
        var backgroundQueue: FakeOperationQueue! = nil

        var moc: NSManagedObjectContext! = nil

        var feeds: [Feed] = []
        var feed1: CoreDataFeed! = nil
        var feed2: CoreDataFeed! = nil
        var feed3: CoreDataFeed! = nil

        var article1: CoreDataArticle! = nil
        var article2: CoreDataArticle! = nil

        var searchIndex: FakeSearchIndex? = nil

        var opmlManager: OPMLManagerMock! = nil

        beforeEach {
            moc = managedObjectContext()

            feed1 = createFeed(moc)
            feed1.title = "a"
            feed1.url = "https://example.com/feed1.feed"
            feed1.tags = ["a", "b", "c"]
            article1 = createArticle(moc)
            article1.title = "b"
            article1.link = "https://example.com/article1.html"
            article2 = createArticle(moc)
            article2.title = "c"
            article1.link = "https://example.com/article2.html"
            article2.read = true
            feed1.addArticlesObject(article1)
            feed1.addArticlesObject(article2)
            article1.feed = feed1
            article2.feed = feed1

            feed2 = createFeed(moc) // query feed
            feed2.title = "d"
            feed2.tags = ["b", "d"]
            feed2.query = "return true"

            feed3 = createFeed(moc)
            feed3.title = "e"
            feed3.url = "https://example.com/feed3.feed"
            feed3.remainingWait = NSNumber(int: 1)
            feed3.tags = ["dad"]
            do {
                try moc.save()
            } catch _ {
            }

            feeds = [feed1, feed2, feed3].map { Feed(feed: $0) }

            searchIndex = FakeSearchIndex()

            mainQueue = FakeOperationQueue()
            backgroundQueue = FakeOperationQueue()
            opmlManager = OPMLManagerMock()
            subject = DataRepository(objectContext: moc, mainQueue: mainQueue, backgroundQueue: backgroundQueue, opmlManager: opmlManager, searchIndex: searchIndex)
        }

        describe("as a DataRetriever") {
            describe("allTags") {
                var calledHandler = false
                var tags: [String] = []

                beforeEach {
                    calledHandler = false

                    subject.allTags {
                        calledHandler = true
                        tags = $0
                    }
                }
                it("should make an asynch call") {
                    expect(calledHandler).to(beFalsy())
                    expect(backgroundQueue.operationCount).to(equal(1))
                    expect(mainQueue.operationCount).to(equal(0))
                }

                describe("when the call finishes") {
                    beforeEach {
                        backgroundQueue.runNextOperation()
                    }

                    it("should let the caller know... on the main thread") {
                        expect(backgroundQueue.operationCount).to(equal(0))
                        expect(mainQueue.operationCount).to(equal(1))

                        expect(calledHandler).to(beFalsy())

                        mainQueue.runNextOperation()

                        expect(mainQueue.operationCount).to(equal(0))
                        expect(calledHandler).to(beTruthy())
                        expect(tags).to(equal(["a", "b", "c", "d", "dad"]))
                    }
                }
            }

            describe("feeds") {
                var calledHandler = false
                var calledFeeds: [Feed] = []

                beforeEach {
                    calledHandler = false

                    subject.feeds {
                        calledHandler = true
                        calledFeeds = $0
                    }
                }

                it("should make an asynch call") {
                    expect(calledHandler).to(beFalsy())
                    expect(backgroundQueue.operationCount).to(equal(1))
                    expect(mainQueue.operationCount).to(equal(0))
                }

                describe("when the call finishes") {
                    beforeEach {
                        backgroundQueue.runNextOperation()
                    }

                    it("should let the caller know... on the main thread") {
                        expect(backgroundQueue.operationCount).to(equal(0))
                        expect(mainQueue.operationCount).to(equal(1))

                        expect(calledHandler).to(beFalsy())

                        mainQueue.runNextOperation()

                        expect(mainQueue.operationCount).to(equal(0))
                        expect(calledHandler).to(beTruthy())
                        expect(calledFeeds).to(equal(feeds))
                    }
                }
            }

            describe("feedsMatchingTag:") {
                var calledHandler = false
                var calledFeeds: [Feed] = []

                beforeEach {
                    calledHandler = false
                }

                context("without a tag/driving out the asynchronous") {
                    beforeEach {
                        subject.feedsMatchingTag(nil) {
                            calledHandler = true
                            calledFeeds = $0
                        }
                    }

                    it("should make an asynch call") {
                        expect(calledHandler).to(beFalsy())
                        expect(backgroundQueue.operationCount).to(equal(1))
                        expect(mainQueue.operationCount).to(equal(0))
                    }

                    describe("when the call finishes") {
                        beforeEach {
                            backgroundQueue.runNextOperation()
                        }

                        it("should let the caller know... on the main thread") {
                            expect(backgroundQueue.operationCount).to(equal(0))
                            expect(mainQueue.operationCount).to(equal(1))

                            expect(calledHandler).to(beFalsy())

                            mainQueue.runNextOperation()

                            expect(mainQueue.operationCount).to(equal(0))
                            expect(calledHandler).to(beTruthy())
                            expect(calledFeeds).to(equal(feeds))
                        }
                    }

                    it("should return all the feeds when no tag, or empty string is given as the tag") {
                        subject.feedsMatchingTag("") {
                            calledHandler = true
                            calledFeeds = $0
                        }
                        backgroundQueue.runNextOperation()
                        mainQueue.runNextOperation()
                        expect(calledFeeds).to(equal(feeds))
                    }
                }

                it("should return feeds that partially match a tag") {
                    let subFeeds = [feed1, feed3].map { Feed(feed: $0) }
                    subject.feedsMatchingTag("a") {
                        calledHandler = true
                        calledFeeds = $0
                    }
                    backgroundQueue.runNextOperation()
                    mainQueue.runNextOperation()
                    expect(calledFeeds).to(equal(subFeeds))
                }
            }

            describe("articlesMatchingQuery") {
                var calledHandler = false
                var calledArticles: [Article] = []

                beforeEach {
                    calledHandler = false

                    subject.articlesMatchingQuery("return !article.read") {
                        calledHandler = true
                        calledArticles = $0
                    }
                }
                
                it("should make an asynch call") {
                    expect(calledHandler).to(beFalsy())
                    expect(backgroundQueue.operationCount).to(equal(1))
                    expect(mainQueue.operationCount).to(equal(0))
                }
                
                describe("when the call finishes") {
                    beforeEach {
                        backgroundQueue.runNextOperation()
                    }
                    
                    it("should let the caller know... on the main thread") {
                        expect(backgroundQueue.operationCount).to(equal(0))
                        expect(mainQueue.operationCount).to(equal(1))
                        
                        expect(calledHandler).to(beFalsy())
                        
                        mainQueue.runNextOperation()
                        
                        expect(mainQueue.operationCount).to(equal(0))
                        expect(calledHandler).to(beTruthy())
                        expect(calledArticles).to(equal([Article(article: article1, feed: nil)]))
                    }
                }
            }
        }

        describe("as a DataWriter") {
            describe("saveFeed") {
                var feed: Feed! = nil
                beforeEach {
                    feed = Feed(feed: feed1)
                    feed.summary = "a changed summary"
                    subject.saveFeed(feed)
                    backgroundQueue.runNextOperation()
                }

                it("should update the data store") {
                    let updatedFeed = DataUtility.entities("Feed", matchingPredicate: NSPredicate(format: "self = %@", feed1.objectID),
                        managedObjectContext: moc).first as? CoreDataFeed
                    expect(updatedFeed?.summary).to(equal(feed.summary))
                    if let updated = updatedFeed {
                        expect(Feed(feed: updated)).to(equal(feed))
                    }
                }
            }

            describe("deleteFeed") {
                var feed: Feed! = nil
                var articleIDs: [String] = []
                beforeEach {
                    feed = Feed(feed: feed1)
                    articleIDs = feed.articles.map { return $0.articleID!.URIRepresentation().absoluteString }
                    subject.deleteFeed(feed)
                    backgroundQueue.runNextOperation()
                }

                it("should remove the feed from the data store") {
                    let feeds = DataUtility.feedsWithPredicate(NSPredicate(value: true), managedObjectContext: moc)
                    expect(feeds.contains(feed)).to(beFalsy())
                }

                it("should remove any articles associated with the feed") {
                    let articles = DataUtility.articlesWithPredicate(NSPredicate(value: true), managedObjectContext: moc)
                    let articleTitles = articles.map { $0.title }
                    expect(articleTitles).toNot(contain("b"))
                    expect(articleTitles).toNot(contain("c"))
                }

                it("should write a new opml file") {
                    expect(opmlManager.didReceiveWriteOPML).to(beTruthy())
                }

                it("should, on iOS 9, remove the articles from the search index") {
                    if #available(iOS 9.0, *) {
                        expect(searchIndex?.lastItemsDeleted).to(equal(articleIDs))
                    }
                }
            }

            describe("markFeedAsRead") {
                beforeEach {
                    subject.markFeedAsRead(Feed(feed: feed1))
                    backgroundQueue.runNextOperation()
                }

                it("should mark every article in the feed as read") {
                    let feed = DataUtility.feedsWithPredicate(NSPredicate(format: "self = %@", feed1.objectID), managedObjectContext: moc).first
                    for article in feed!.articles {
                        expect(article.read).to(beTruthy())
                    }
                }
            }

            describe("saveArticle") {
                var article: Article! = nil

                beforeEach {
                    let feed = Feed(feed: feed1)
                    article = feed.articles.first

                    let coreDataArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                        managedObjectContext: moc).first
                    expect(coreDataArticle).toNot(beNil())
                    article.title = "hello"
                    subject.saveArticle(article)
                    backgroundQueue.runNextOperation()
                }

                it("should update the data store") {
                    let updatedArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                        managedObjectContext: moc).first as? CoreDataArticle
                    expect(updatedArticle?.title).to(equal(article.title))
                    if let updated = updatedArticle {
                        expect(Article(article: updated, feed: nil)).to(equal(article))
                    }
                }

                it("should, on iOS 9, update the search index") {
                    if #available(iOS 9.0, *) {
                        expect(searchIndex?.lastItemsAdded.count).to(equal(1))
                        if let item = searchIndex?.lastItemsAdded.first as? CSSearchableItem {
                            let identifier = article.articleID!.URIRepresentation().absoluteString
                            expect(item.uniqueIdentifier).to(equal(identifier))
                            expect(item.domainIdentifier).to(beNil())
                            expect(item.expirationDate).to(equal(NSDate.distantFuture()))
                            let attributes = item.attributeSet
                            expect(attributes.contentType).to(equal(kUTTypeHTML as String))
                            expect(attributes.title).to(equal(article.title))
                            let keywords = ["article"] + article.feed!.title.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                            expect(attributes.keywords).to(equal(keywords))
                            expect(attributes.URL).to(equal(article.link))
                            expect(attributes.timestamp).to(equal(article.updatedAt ?? article.published))
                            expect(attributes.authorNames).to(equal([article.author]))
                            expect(attributes.contentDescription).to(equal(article.summary))
                        }
                    }
                }
            }

            describe("deleteArticle") {
                var article: Article! = nil

                beforeEach {
                    let feed = Feed(feed: feed1)
                    article = feed.articles.first

                    let coreDataArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                        managedObjectContext: moc).first
                    expect(coreDataArticle).toNot(beNil())
                    subject.deleteArticle(article)
                    backgroundQueue.runNextOperation()
                }

                it("should remove the article from the data store") {
                    let coreDataArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                        managedObjectContext: moc).first
                    expect(coreDataArticle).to(beNil())
                }

                it("should, on iOS 9, remove the article from the search index") {
                    if #available(iOS 9.0, *) {
                        let identifier = article.articleID!.URIRepresentation().absoluteString
                        expect(searchIndex?.lastItemsDeleted).to(equal([identifier]))
                    }
                }
            }

            describe("markArticle:asRead:") {
                var article: Article! = nil

                beforeEach {
                    let feed = Feed(feed: feed1)
                    article = feed.articles.first

                    subject.markArticle(article, asRead: true)
                    backgroundQueue.runNextOperation()
                }

                it("should mark the article as read in the data store") {
                    let coreDataArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                        managedObjectContext: moc).first
                    expect(coreDataArticle).toNot(beNil())
                    if let cda = coreDataArticle as? CoreDataArticle {
                        expect(cda.read).to(beTruthy())
                    }
                }

                describe("and marking it as unread again") {
                    beforeEach {
                        subject.markArticle(article, asRead: false)
                        backgroundQueue.runNextOperation()
                    }

                    it("should mark the article as unread in the data store") {
                        let coreDataArticle = DataUtility.entities("Article", matchingPredicate: NSPredicate(format: "self = %@", article.articleID!),
                            managedObjectContext: moc).first
                        expect(coreDataArticle).toNot(beNil())
                        if let cda = coreDataArticle as? CoreDataArticle {
                            expect(cda.read).to(beFalsy())
                        }
                    }
                }
            }

            describe("updateFeeds") {
                //
            }
        }
    }
}

import Quick
import Nimble
#if os(iOS)
    import CoreSpotlight
    import MobileCoreServices
#endif

@testable import rNewsKit

class InMemoryDataServiceSpec: QuickSpec {
    override func spec() {
        var mainQueue = FakeOperationQueue()
        mainQueue.runSynchronously = true
        var searchIndex = FakeSearchIndex()

        var subject = InMemoryDataService(mainQueue: mainQueue, searchIndex: searchIndex)

        beforeEach {
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            searchIndex = FakeSearchIndex()

            subject = InMemoryDataService(mainQueue: mainQueue, searchIndex: searchIndex)
        }

        describe("create operations") {
            it("new feed creates a new feed object") {
                let expectation = self.expectationWithDescription("Create Feed")

                subject.createFeed { feed in
                    feed.title = "Hello"
                    feed.url = NSURL(string: "https://example.com/feed")
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1, handler: nil)

                let feeds = subject.feeds
                expect(feeds.count) == 1
                guard let feed = feeds.first else { return }
                expect(feed.title) == "Hello"
                expect(feed.url) == NSURL(string: "https://example.com/feed")
            }

            it("new article creates a new article object") {
                let expectation = self.expectationWithDescription("Create Article")

                subject.createArticle(nil) { article in
                    article.title = "Hello"
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1, handler: nil)

                let articles = subject.articles
                expect(articles.count) == 1
                guard let article = articles.first else { return }
                expect(article.title) == "Hello"
            }

            it("new enclosure creates a new enclosure object") {
                let expectation = self.expectationWithDescription("Create Enclosure")

                subject.createEnclosure(nil) { enclosure in
                    enclosure.kind = "hi"
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1, handler: nil)

                let enclosures = subject.enclosures
                expect(enclosures.count) == 1
                expect(enclosures.first?.kind) == "hi"
            }
        }

        describe("after creates") {
            var feed1: rNewsKit.Feed!
            var feed2: rNewsKit.Feed!
            var article1: rNewsKit.Article!
            var article2: rNewsKit.Article!
            var article3: rNewsKit.Article!
            var enclosure1: rNewsKit.Enclosure!
            var enclosure2: rNewsKit.Enclosure!

            beforeEach {
                feed1 = Feed(title: "feed1", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                feed2 = Feed(title: "feed2", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                article1 = Article(title: "article1", link: NSURL(string: "https://example.com/article1"), summary: "",
                    authors: [], published: NSDate(timeIntervalSince1970: 15), updatedAt: nil, identifier: "",
                    content: "", read: false, estimatedReadingTime: 0, feed: feed1, flags: [], enclosures: [])
                feed1.addArticle(article1)

                article2 = Article(title: "article2", link: nil, summary: "", authors: [],
                    published: NSDate(timeIntervalSince1970: 10), updatedAt: nil, identifier: "", content: "",
                    read: false, estimatedReadingTime: 0, feed: feed1, flags: [], enclosures: [])
                feed1.addArticle(article2)

                article3 = Article(title: "article3", link: nil, summary: "", authors: [],
                    published: NSDate(timeIntervalSince1970: 5), updatedAt: nil, identifier: "", content: "",
                    read: false, estimatedReadingTime: 0, feed: feed2, flags: [], enclosures: [])
                feed2.addArticle(article3)

                article3.relatedArticles.append(article2)
                article2.relatedArticles.append(article3)

                enclosure1 = Enclosure(url: NSURL(string: "")!, kind: "1", article: article1)
                article1.addEnclosure(enclosure1)
                enclosure2 = Enclosure(url: NSURL(string: "")!, kind: "2", article: article2)
                article2.addEnclosure(enclosure2)

                subject.feeds = [feed1, feed2]
                subject.articles = [article1, article2, article3]
                subject.enclosures = [enclosure1, enclosure2]
            }

            describe("read operations") {
                it("reads the feeds based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all feeds")
                    subject.feedsMatchingPredicate(NSPredicate(value: true)).then {
                        expect(Array($0)) == [feed1, feed2]
                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectationWithDescription("Read some feeds")
                    subject.feedsMatchingPredicate(NSPredicate(format: "title == %@", "feed1")).then {
                        expect(Array($0)) == [feed1]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }

                it("reads the articles based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all articles")
                    subject.articlesMatchingPredicate(NSPredicate(value: true)).then { articles in
                        expect(Array(articles)) == [article1, article2, article3]

                        expect(articles[1].relatedArticles).to(contain(article3))
                        expect(articles[2].relatedArticles).to(contain(article2))

                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectationWithDescription("Read some articles")
                    subject.articlesMatchingPredicate(NSPredicate(format: "title == %@", "article1")).then {
                        expect(Array($0)) == [article1]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }

                it("reads all enclosures based on the predicate") {
                    let allExpectation = self.expectationWithDescription("Read all enclosures")
                    subject.enclosuresMatchingPredicate(NSPredicate(value: true)).then {
                        expect(Array($0)) == [enclosure1, enclosure2]
                        allExpectation.fulfill()
                    }

                    let someExpectation = self.expectationWithDescription("Read some enclosures")
                    subject.enclosuresMatchingPredicate(NSPredicate(format: "kind == %@", "1")).then {
                        expect(Array($0)) == [enclosure1]
                        someExpectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }

            describe("update operations") {
                it("updates a feed") {
                    let expectation = self.expectationWithDescription("update feed")

                    feed1.summary = "hello world"

                    subject.saveFeed(feed1).then {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let feed = subject.feeds.first
                    expect(feed).toNot(beNil())
                    expect(feed?.summary) == "hello world"
                }

                it("updates an article") {
                    let expectation = self.expectationWithDescription("update article")

                    article1.summary = "hello world"
                    article1.addRelatedArticle(article2)

                    subject.saveArticle(article1).then {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let article = subject.articles.first
                    expect(article?.summary) == "hello world"
                    expect(article?.relatedArticles).toNot(beEmpty())
                }

                it("updates an enclosure") {
                    let expectation = self.expectationWithDescription("update enclosure")

                    enclosure1.kind = "3"

                    subject.saveEnclosure(enclosure1).then {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    let enclosure = subject.enclosures.first
                    expect(enclosure?.kind) == "3"
                }
            }

            describe("delete operations") {
                it("deletes feeds") {
                    let expectation = self.expectationWithDescription("delete feed")

                    subject.deleteFeed(feed1).then {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    expect(subject.feeds).toNot(contain(feed1))
                    expect(subject.articles).toNot(contain(article1))
                    expect(subject.articles).toNot(contain(article2))
                    expect(subject.enclosures).to(beEmpty())
                }

                it("deletes articles") {
                    let expectation = self.expectationWithDescription("delete article")

                    subject.deleteArticle(article1).then {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    expect(subject.articles).toNot(contain(article1))
                    expect(subject.enclosures).toNot(contain(enclosure1))
                }

                it("deletes enclosures") {
                    let expectation = self.expectationWithDescription("delete enclosure")

                    subject.deleteEnclosure(enclosure1).then {
                        expectation.fulfill()
                    }

                    self.waitForExpectationsWithTimeout(1, handler: nil)

                    expect(subject.enclosures).toNot(contain(enclosure1))
                }
            }
        }
    }
}

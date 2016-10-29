import Quick
import Nimble
import Result
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
                _ = subject.createFeed(url: URL(string: "https://example.com/feed")!) { feed in
                    feed.title = "Hello"
                }.wait()

                let feeds = subject.feeds
                expect(feeds.count) == 1
                guard let feed = feeds.first else { return }
                expect(feed.title) == "Hello"
                expect(feed.url) == URL(string: "https://example.com/feed")
            }

            it("new article creates a new article object") {
                let expectation = self.expectation(description: "Create Article")

                subject.createArticle(url: URL(string: "https://example.com/article")!, feed: nil) { article in
                    article.title = "Hello"
                    expectation.fulfill()
                }

                self.waitForExpectations(timeout: 1, handler: nil)

                let articles = subject.articles
                expect(articles.count) == 1
                guard let article = articles.first else { return }
                expect(article.title) == "Hello"
                expect(article.link) ==  URL(string: "https://example.com/article")
            }
        }

        describe("findOrCreateFeed") {
            beforeEach {
                let feed1 = Feed(title: "feed1", url: URL(string: "https://example.com/feed/feed1")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                subject.feeds = [feed1]
            }

            it("finds an existing feed if that url exists") {
                let future = subject.findOrCreateFeed(url: URL(string: "https://example.com/feed/feed1")!)
                expect(future.value).toNot(beNil())
                let feed = future.value
                expect(feed?.url) == URL(string: "https://example.com/feed/feed1")

                expect(subject.feeds.count) == 1
            }

            it("creates a new feed if that url does not exist") {
                let future = subject.findOrCreateFeed(url: URL(string: "https://example.com/feed/feed2")!)
                expect(future.value).toNot(beNil())
                let feed = future.value
                expect(feed?.url) == URL(string: "https://example.com/feed/feed2")

                expect(subject.feeds.count) == 2
            }
        }

        describe("findOrCreateArticle") {
            let feed1 = Feed(title: "feed1", url: URL(string: "https://example.com/feed/feed1")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            let article1 = Article(title: "article", link: URL(string: "https://example.com/article/article1")!, summary: "", authors: [],
                                   published: Date(), updatedAt: nil, identifier: "", content: "", read: false, estimatedReadingTime: 0,
                                   feed: feed1, flags: [])
            feed1.addArticle(article1)
            beforeEach {
                subject.feeds = [feed1]
                subject.articles = [article1]
            }

            it("finds an existing article if an article of that feed for that url exists") {
                let future = subject.findOrCreateArticle(feed: feed1, url: URL(string: "https://example.com/article/article1")!)
                expect(future.value).toNot(beNil())
                let article = future.value
                expect(article?.link) == URL(string: "https://example.com/article/article1")

                expect(subject.articles.count) == 1
            }

            it("creates a new article if that url does not exist") {
                let future = subject.findOrCreateArticle(feed: feed1, url: URL(string: "https://example.com/article/article2")!)
                expect(future.value).toNot(beNil())
                let article = future.value
                expect(article?.link) == URL(string: "https://example.com/article/article2")

                expect(subject.articles.count) == 2
            }

            it("creates a new feed and article if the feed does not exist") {
                let feed2 = Feed(title: "feed2", url: URL(string: "https://example.com/feed/feed2")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let future = subject.findOrCreateArticle(feed: feed2, url: URL(string: "https://example.com/article/article2")!)
                expect(future.value).toNot(beNil())
                let article = future.value
                expect(article?.link) == URL(string: "https://example.com/article/article2")
                expect(article?.feed) == feed2

                expect(subject.feeds.count) == 2
                expect(subject.articles.count) == 2
            }
        }

        describe("after creates") {
            var feed1: rNewsKit.Feed!
            var feed2: rNewsKit.Feed!
            var article1: rNewsKit.Article!
            var article2: rNewsKit.Article!
            var article3: rNewsKit.Article!

            beforeEach {
                feed1 = Feed(title: "feed1", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                feed2 = Feed(title: "feed2", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                article1 = Article(title: "article1", link: URL(string: "https://example.com/article1")!, summary: "",
                    authors: [], published: Date(timeIntervalSince1970: 15), updatedAt: nil, identifier: "",
                    content: "", read: false, estimatedReadingTime: 0, feed: feed1, flags: [])
                feed1.addArticle(article1)

                article2 = Article(title: "article2", link: URL(string: "https://example.com/article2")!, summary: "", authors: [],
                    published: Date(timeIntervalSince1970: 10), updatedAt: nil, identifier: "", content: "",
                    read: false, estimatedReadingTime: 0, feed: feed1, flags: [])
                feed1.addArticle(article2)

                article3 = Article(title: "article3", link: URL(string: "https://example.com/article3")!, summary: "", authors: [],
                    published: Date(timeIntervalSince1970: 5), updatedAt: nil, identifier: "", content: "",
                    read: false, estimatedReadingTime: 0, feed: feed2, flags: [])
                feed2.addArticle(article3)

                article3.relatedArticles.append(article2)
                article2.relatedArticles.append(article3)

                subject.feeds = [feed1, feed2]
                subject.articles = [article1, article2, article3]
            }

            describe("read operations") {
                it("reads the feeds based on the predicate") {
                    _ = subject.allFeeds().then {
                        guard case let Result.success(feeds) = $0 else { return }
                        expect(Array(feeds)) == [feed1, feed2]
                    }.wait()
                }

                it("reads the articles based on the predicate") {
                    _ = subject.articlesMatchingPredicate(NSPredicate(value: true)).then {
                        guard case let Result.success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1, article2, article3]

                        expect(articles[1].relatedArticles.contains(article3)).to(beTruthy())
                        expect(articles[2].relatedArticles.contains(article2)).to(beTruthy())
                    }.wait()

                    _ = subject.articlesMatchingPredicate(NSPredicate(format: "title == %@", "article1")).then {
                        guard case let Result.success(articles) = $0 else { return }
                        expect(Array(articles)) == [article1]
                    }.wait()
                }
            }

            describe("delete operations") {
                it("deletes feeds") {
                    _ = subject.deleteFeed(feed1).wait()

                    expect(subject.feeds).toNot(contain(feed1))
                    expect(subject.articles).toNot(contain(article1))
                    expect(subject.articles).toNot(contain(article2))
                }

                it("deletes articles") {
                    let expectation = self.expectation(description: "delete article")

                    _ = subject.deleteArticle(article1).then {
                        guard case Result.success() = $0 else { return }
                        expectation.fulfill()
                    }

                    self.waitForExpectations(timeout: 1, handler: nil)

                    expect(subject.articles).toNot(contain(article1))
                }
            }
        }
    }
}

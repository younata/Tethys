import Quick
import Nimble
import CoreData
import Result
@testable import rNewsKit

func dataServiceSharedSpec(_ dataService: DataService, spec: QuickSpec) {
    describe("feeds") {
        var feed: rNewsKit.Feed?

        beforeEach {
            let createExpectation = spec.expectation(description: "Create Feed")
            _ = dataService.createFeed {
                feed = $0
                createExpectation.fulfill()
            }
            spec.waitForExpectations(timeout: 1, handler: nil)
            expect(feed).toNot(beNil())
        }

        afterEach {
            if let feed = feed {
                let deleteFeedExpectation = spec.expectation(description: "Delete Feed")
                _ = dataService.deleteFeed(feed).then {
                    if case Result.success() = $0 {
                        deleteFeedExpectation.fulfill()
                    }
                }
                spec.waitForExpectations(timeout: 1, handler: nil)
            }
        }

        it("easily allows a feed to be updated with inserted articles") {
            guard let feed = feed else { fail(); return }
            let itemUpdateDate = Date(timeIntervalSinceNow: -5)
            let item = FakeImportableArticle(title: "article", url: URL(string: "/foo/bar/baz")!, summary: "", content: "", published: Date(), updated: nil, authors: [])
            let info = FakeImportableFeed(title: "a &amp; title", link: URL(string: "https://example.com")!, description: "description", lastUpdated: itemUpdateDate, imageURL: nil, articles: [item])
            let updateExpectation = spec.expectation(description: "Update Feed")
            _ = dataService.updateFeed(feed, info: info).then {
                if case Result.success() = $0 {
                    updateExpectation.fulfill()
                }
            }
            spec.waitForExpectations(timeout: 1, handler: nil)

            expect(feed.title) == "a & title"
            expect(feed.summary) == "description"
            expect(feed.url) == URL(string: "")
            expect(feed.lastUpdated) == itemUpdateDate
            expect(feed.articlesArray.count).to(equal(1))
            if let article = feed.articlesArray.first {
                expect(article.title) == "article"
            }
        }

        it("makes the item link relative to the feed link in the event the item link has a nil scheme") {
            guard let feed = feed else { fail(); return }
            let item = FakeImportableArticle(title: "article", url: URL(string: "/foo/bar/baz")!, summary: "", content: "", published: Date(), updated: nil, authors: [])
            let info = FakeImportableFeed(title: "a &amp; title", link: URL(string: "https://example.com/qux")!, description: "description", lastUpdated: Date(), imageURL: nil, articles: [item])
            _ = dataService.updateFeed(feed, info: info).wait()

            expect(feed.title) == "a & title"
            expect(feed.summary) == "description"
            expect(feed.url) == URL(string: "")
            expect(feed.articlesArray.count).to(equal(1))
            if let article = feed.articlesArray.first {
                expect(article.title) == "article"
                expect(article.link) == URL(string: "https://example.com/foo/bar/baz")
            }
        }

        it("does not insert items that have empty titles") {
            guard let feed = feed else { fail(); return }
            let item = FakeImportableArticle(title: "", url: URL(string: "/foo/bar/baz")!, summary: "", content: "", published: Date(), updated: nil, authors: [])
            let info = FakeImportableFeed(title: "a title", link: URL(string: "https://example.com")!, description: "description", lastUpdated: Date(), imageURL: nil, articles: [item])
            _ = dataService.updateFeed(feed, info: info).wait()

            expect(feed.title) == "a title"
            expect(feed.summary) == "description"
            expect(feed.url) == URL(string: "")
            expect(feed.articlesArray.count).to(equal(0))
        }

        it("easily updates an existing feed that has articles with new articles") {
            guard let feed = feed else { fail(); return }
            var existingArticle: rNewsKit.Article! = nil
            let addArticleExpectation = spec.expectation(description: "existing article")

            dataService.createArticle(feed) { article in
                existingArticle = article
                existingArticle.title = "blah"
                existingArticle.link = URL(string: "https://example.com/article")
                existingArticle.summary = "summary"
                existingArticle.content = "content"
                existingArticle.published = Date(timeIntervalSince1970: 10)
                expect(existingArticle.feed) == feed
                addArticleExpectation.fulfill()
            }
            spec.waitForExpectations(timeout: 1, handler: nil)

            expect(feed.articlesArray).to(contain(existingArticle))
            expect(feed.articlesArray.count) == 1

            let existingItem = FakeImportableArticle(title: existingArticle.title, url: existingArticle.link!, summary: existingArticle.summary, content: existingArticle.content, published: existingArticle.published, updated: nil, authors: [])
            let item = FakeImportableArticle(title: "article", url: URL(string: "")!, summary: "", content: "", published: Date(), updated: nil, authors: [])
            let info = FakeImportableFeed(title: "a title", link: URL(string: "https://example.com")!, description: "description", lastUpdated: Date(), imageURL: nil, articles: [existingItem, item])
            _ = dataService.updateFeed(feed, info: info).then {
                guard case Result.success() = $0 else { return }
                expect(feed.title) == "a title"
                expect(feed.summary) == "description"
                expect(feed.url) == URL(string: "")
                expect(feed.lastUpdated) == info.lastUpdated
                expect(feed.articlesArray.count).to(equal(2))
                let articles = feed.articlesArray
                if let firstArticle = articles.first {
                    expect(firstArticle) == existingArticle
                }
                if let secondArticle = articles.last {
                    expect(secondArticle.title) == item.title
                    expect(secondArticle.link) == URL(string: "https://example.com")
                    expect(secondArticle) != existingArticle
                }
            }.wait()
        }
    }

    describe("articles") {
        var article: rNewsKit.Article?

        beforeEach {
            let createExpectation = spec.expectation(description: "Create Article")
            dataService.createArticle(nil) {
                article = $0
                createExpectation.fulfill()
            }
            spec.waitForExpectations(timeout: 1, handler: nil)
            expect(article).toNot(beNil())
        }

        afterEach {
            if let article = article {
                _ = dataService.deleteArticle(article).wait()
            }
        }

        it("searches an item's content for links matching current articles, and adds them to the related articles list") {
            var otherArticle: rNewsKit.Article?
            let createExpectation = spec.expectation(description: "Create Article")
            dataService.createArticle(nil) {
                otherArticle = $0
                $0.link = URL(string: "https://example.com/foo/bar/")
                createExpectation.fulfill()
            }
            spec.waitForExpectations(timeout: 1, handler: nil)
            expect(otherArticle).toNot(beNil())

            let content = "<html><body><a href=\"/foo/bar/\"></a></body></html>"

            let item = FakeImportableArticle(title: "a <p></p>&amp; title", url: URL(string: "https://example.com/foo/baz")!, summary: "description", content: content, published: Date(timeIntervalSince1970: 10), updated: Date(timeIntervalSince1970: 15), authors: [])

            _ = dataService.updateArticle(article!, item: item, feedURL: URL(string: "https://example.com/")!).wait()
            expect(article!.relatedArticles).to(contain(otherArticle!))
        }

        it("easily allows an article to be updated, filtering out title information") {
            guard let article = article else { fail(); return }
            let author = FakeImportableAuthor(name: "Rachel Brindle", email: URL(string: "mailto:rachel@example.com"))
            let content = (0..<100).map({_ in "<p>this was a content space</p>"}).reduce("", +)

            let item = FakeImportableArticle(title: "a <p></p>&amp; title", url: URL(string: "https://example.com")!, summary: "description", content: content, published: Date(timeIntervalSince1970: 10), updated: Date(timeIntervalSince1970: 15), authors: [author])

            if let searchIndex = dataService.searchIndex as? FakeSearchIndex {
                searchIndex.lastItemsAdded = []
            }
            _ = dataService.updateArticle(article, item: item, feedURL: URL(string: "https://example.com/foo/bar/baz")!).wait()
            expect(article.title) == "a & title"
            expect(article.link) == URL(string: "https://example.com")
            expect(article.published) == Date(timeIntervalSince1970: 10)
            expect(article.updatedAt) == Date(timeIntervalSince1970: 15)
            expect(article.summary) == "description"
            expect(article.content) == content
            expect(article.authors) == [Author(name: "Rachel Brindle", email: URL(string: "mailto:rachel@example.com"))]
            expect(article.estimatedReadingTime) == 3
        }
    }
}


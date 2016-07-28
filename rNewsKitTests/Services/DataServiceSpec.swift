import Quick
import Nimble
import CoreData
import Result
@testable import rNewsKit

func dataServiceSharedSpec(dataService: DataService, spec: QuickSpec) {
    describe("feeds") {
        var feed: rNewsKit.Feed?

        beforeEach {
            let createExpectation = spec.expectationWithDescription("Create Feed")
            dataService.createFeed {
                feed = $0
                createExpectation.fulfill()
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)
            expect(feed).toNot(beNil())
        }

        afterEach {
            if let feed = feed {
                let deleteFeedExpectation = spec.expectationWithDescription("Delete Feed")
                dataService.deleteFeed(feed).then {
                    if case Result.Success() = $0 {
                        deleteFeedExpectation.fulfill()
                    }
                }
                spec.waitForExpectationsWithTimeout(1, handler: nil)
            }
        }

        it("easily allows a feed to be updated with inserted articles") {
            guard let feed = feed else { fail(); return }
            let fakeEnclosure = FakeImportableEnclosure(url: NSURL(string: "https://example.com/enclosure.mp3")!, length: 0, type: "audio/mpeg")
            let item = FakeImportableArticle(title: "article", url: NSURL(string: "/foo/bar/baz")!, summary: "", content: "", published: NSDate(), updated: nil, authors: [], enclosures: [fakeEnclosure])
            let info = FakeImportableFeed(title: "a &amp; title", link: NSURL(string: "https://example.com")!, description: "description", imageURL: nil, articles: [item])
            let updateExpectation = spec.expectationWithDescription("Update Feed")
            dataService.updateFeed(feed, info: info).then {
                if case Result.Success() = $0 {
                    updateExpectation.fulfill()
                }
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)

            expect(feed.title) == "a & title"
            expect(feed.summary) == "description"
            expect(feed.url).to(beNil())
            expect(feed.articlesArray.count).to(equal(1))
            if let article = feed.articlesArray.first {
                expect(article.title) == "article"
                expect(article.enclosuresArray.count).to(equal(1))
                if let enclosure = article.enclosuresArray.first {
                    expect(enclosure.kind) == fakeEnclosure.type
                    expect(enclosure.url) == fakeEnclosure.url
                }
            }
        }

        it("makes the item link relative to the feed link in the event the item link has a nil scheme") {
            guard let feed = feed else { fail(); return }
            let item = FakeImportableArticle(title: "article", url: NSURL(string: "/foo/bar/baz")!, summary: "", content: "", published: NSDate(), updated: nil, authors: [], enclosures: [])
            let info = FakeImportableFeed(title: "a &amp; title", link: NSURL(string: "https://example.com/qux")!, description: "description", imageURL: nil, articles: [item])
            let updateExpectation = spec.expectationWithDescription("Update Feed")
            dataService.updateFeed(feed, info: info).then {
                if case Result.Success() = $0 {
                    updateExpectation.fulfill()
                }
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)

            expect(feed.title) == "a & title"
            expect(feed.summary) == "description"
            expect(feed.url).to(beNil())
            expect(feed.articlesArray.count).to(equal(1))
            if let article = feed.articlesArray.first {
                expect(article.title) == "article"
                expect(article.link) == NSURL(string: "https://example.com/foo/bar/baz")
            }
        }

        it("does not insert items that have empty titles") {
            guard let feed = feed else { fail(); return }
            let item = FakeImportableArticle(title: "", url: NSURL(string: "/foo/bar/baz")!, summary: "", content: "", published: NSDate(), updated: nil, authors: [], enclosures: [])
            let info = FakeImportableFeed(title: "a title", link: NSURL(string: "https://example.com")!, description: "description", imageURL: nil, articles: [item])
            let updateExpectation = spec.expectationWithDescription("Update Feed")
            dataService.updateFeed(feed, info: info).then {
                if case Result.Success() = $0 {
                    updateExpectation.fulfill()
                }
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)

            expect(feed.title) == "a title"
            expect(feed.summary) == "description"
            expect(feed.url).to(beNil())
            expect(feed.articlesArray.count).to(equal(0))
        }

        it("easily updates an existing feed that has articles with new articles") {
            guard let feed = feed else { fail(); return }
            var existingArticle: rNewsKit.Article! = nil
            let addArticleExpectation = spec.expectationWithDescription("existing article")

            dataService.createArticle(feed) { article in
                existingArticle = article
                existingArticle.title = "blah"
                existingArticle.link = NSURL(string: "https://example.com/article")
                existingArticle.summary = "summary"
                existingArticle.content = "content"
                existingArticle.published = NSDate(timeIntervalSince1970: 10)
                expect(existingArticle.feed) == feed
                addArticleExpectation.fulfill()
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)

            expect(feed.articlesArray).to(contain(existingArticle))
            expect(feed.articlesArray.count) == 1

            let existingItem = FakeImportableArticle(title: existingArticle.title, url: existingArticle.link!, summary: existingArticle.summary, content: existingArticle.content, published: existingArticle.published, updated: nil, authors: [], enclosures: [])
            let item = FakeImportableArticle(title: "article", url: NSURL(string: "")!, summary: "", content: "", published: NSDate(), updated: nil, authors: [], enclosures: [])
            let info = FakeImportableFeed(title: "a title", link: NSURL(string: "https://example.com")!, description: "description", imageURL: nil, articles: [existingItem, item])
            let updateExpectation = spec.expectationWithDescription("Update Feed")
            dataService.updateFeed(feed, info: info).then {
                guard case Result.Success() = $0 else { return }
                expect(feed.title) == "a title"
                expect(feed.summary) == "description"
                expect(feed.url).to(beNil())
                expect(feed.articlesArray.count).to(equal(2))
                let articles = feed.articlesArray
                if let firstArticle = articles.first {
                    expect(firstArticle) == existingArticle
                }
                if let secondArticle = articles.last {
                    expect(secondArticle.title) == item.title
                    expect(secondArticle.link) == NSURL(string: "https://example.com")
                    expect(secondArticle) != existingArticle
                }
                updateExpectation.fulfill()
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)
        }
    }

    describe("articles") {
        var article: rNewsKit.Article?

        beforeEach {
            let createExpectation = spec.expectationWithDescription("Create Article")
            dataService.createArticle(nil) {
                article = $0
                createExpectation.fulfill()
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)
            expect(article).toNot(beNil())
        }

        afterEach {
            if let article = article {
                let deleteExpectation = spec.expectationWithDescription("Delete Article")
                dataService.deleteArticle(article).then {
                    guard case Result.Success() = $0 else { return }

                    deleteExpectation.fulfill()
                }
                spec.waitForExpectationsWithTimeout(1, handler: nil)
            }
        }

        it("searches an item's content for links matching current articles, and adds them to the related articles list") {
            var otherArticle: rNewsKit.Article?
            let createExpectation = spec.expectationWithDescription("Create Article")
            dataService.createArticle(nil) {
                otherArticle = $0
                $0.link = NSURL(string: "https://example.com/foo/bar/")
                createExpectation.fulfill()
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)
            expect(otherArticle).toNot(beNil())

            let content = "<html><body><a href=\"/foo/bar/\"></a></body></html>"

            let item = FakeImportableArticle(title: "a <p></p>&amp; title", url: NSURL(string: "https://example.com/foo/baz")!, summary: "description", content: content, published: NSDate(timeIntervalSince1970: 10), updated: NSDate(timeIntervalSince1970: 15), authors: [], enclosures: [])

            let updateExpectation = spec.expectationWithDescription("Update Article")
            dataService.updateArticle(article!, item: item, feedURL: NSURL(string: "https://example.com/")!).then { _ in
                expect(article!.relatedArticles).to(contain(otherArticle!))
                updateExpectation.fulfill()
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)
        }

        it("easily allows an article to be updated, filtering out title information") {
            guard let article = article else { fail(); return }
            let author = FakeImportableAuthor(name: "Rachel Brindle", email: NSURL(string: "mailto:rachel@example.com"))
            let content = (0..<100).map({_ in "<p>this was a content space</p>"}).reduce("", combine: +)

            let muonEnclosure = FakeImportableEnclosure(url: NSURL(string: "https://example.com/enclosure.mp3")!, length: 0, type: "audio/mpeg")
            let item = FakeImportableArticle(title: "a <p></p>&amp; title", url: NSURL(string: "https://example.com")!, summary: "description", content: content, published: NSDate(timeIntervalSince1970: 10), updated: NSDate(timeIntervalSince1970: 15), authors: [author], enclosures: [muonEnclosure])

            let updateExpectation = spec.expectationWithDescription("Update Article")
            if let searchIndex = dataService.searchIndex as? FakeSearchIndex {
                searchIndex.lastItemsAdded = []
            }
            dataService.updateArticle(article, item: item, feedURL: NSURL(string: "https://example.com/foo/bar/baz")!).then { _ in
                expect(article.title) == "a & title"
                expect(article.link) == NSURL(string: "https://example.com")
                expect(article.published) == NSDate(timeIntervalSince1970: 10)
                expect(article.updatedAt) == NSDate(timeIntervalSince1970: 15)
                expect(article.summary) == "description"
                expect(article.content) == content
                expect(article.authors) == [Author(name: "Rachel Brindle", email: NSURL(string: "mailto:rachel@example.com"))]
                expect(article.estimatedReadingTime) == 3
                expect(article.enclosuresArray.count).to(equal(1))
                if let enclosure = article.enclosuresArray.first {
                    expect(enclosure.kind) == muonEnclosure.type
                    expect(enclosure.url) == muonEnclosure.url
                }
                updateExpectation.fulfill()
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)
        }

        describe("updating enclosures") {
            let muonEnclosure = FakeImportableEnclosure(url: NSURL(string: "https://example.com")!, length: 10, type: "html")
            var enclosure: rNewsKit.Enclosure?

            afterEach {
                if let _ = enclosure {
                    let deleteExpectation = spec.expectationWithDescription("Delete Enclosure")
                    dataService.deleteEverything().then {
                        guard case Result.Success() = $0 else { return }

                        deleteExpectation.fulfill()
                    }
                    spec.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }

            context("when the given article has an existing enclosure object matching the given one") {
                beforeEach {
                    let createExpectation = spec.expectationWithDescription("Create Enclosure")
                    dataService.createEnclosure(nil) {
                        $0.url = NSURL(string: "https://example.com")!
                        $0.kind = "html"
                        article?.addEnclosure($0)
                        enclosure = $0
                        createExpectation.fulfill()
                    }
                    spec.waitForExpectationsWithTimeout(1, handler: nil)
                    expect(enclosure).toNot(beNil())
                }

                it("essentially no-ops, and specifically does not add another enclosure to the article") {
                    guard let article = article else { fail(); return; }
                    let upsertExpectation = spec.expectationWithDescription("Upsert Enclosure")
                    dataService.upsertEnclosureForArticle(article, fromItem: muonEnclosure).then { _ in
                        upsertExpectation.fulfill()
                    }

                    spec.waitForExpectationsWithTimeout(1, handler: nil)

                    expect(article.enclosuresArray.count) == 1
                }
            }

            context("when the given article does not have an existing enclosure object matching the given one") {
                it("creates a new enclosure and inserts that into the article") {
                    guard let article = article else { fail(); return; }
                    dataService.upsertEnclosureForArticle(article, fromItem: muonEnclosure)

                    let findExpectation = spec.expectationWithDescription("Find Enclosure")

                    dataService.articlesMatchingPredicate(NSPredicate(value: true)).then {
                        guard case let Result.Success(articles) = $0 else { return }
                        let article = articles.first!
                        expect(article.enclosuresArray.count) == 1
                        expect(article.enclosuresArray.first?.url) == NSURL(string: "https://example.com")!
                        expect(article.enclosuresArray.first?.kind) == "html"
                        findExpectation.fulfill()
                    }

                    spec.waitForExpectationsWithTimeout(1, handler: nil)
                }
            }
        }
    }
}


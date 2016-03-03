import Quick
import Nimble
import CoreData
@testable import rNewsKit
import Muon

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
                dataService.deleteFeed(feed) {
                    deleteFeedExpectation.fulfill()
                }
                spec.waitForExpectationsWithTimeout(1, handler: nil)
            }
        }

        it("easily allows a feed to be updated with inserted articles") {
            guard let feed = feed else { fail(); return }
            let muonEnclosure = Muon.Enclosure(url: NSURL(string: "https://example.com/enclosure.mp3")!, length: 0, type: "audio/mpeg")
            let item = Muon.Article(title: "article", link: nil, description: "", content: "", guid: "", published: nil, updated: nil, authors: [], enclosures: [muonEnclosure])
            let info = Muon.Feed(title: "a &amp; title", link: NSURL(string: "https://example.com")!, description: "description", articles: [item])
            let updateExpectation = spec.expectationWithDescription("Update Feed")
            dataService.updateFeed(feed, info: info) {
                updateExpectation.fulfill()
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
                    expect(enclosure.kind) == muonEnclosure.type
                    expect(enclosure.url) == muonEnclosure.url
                }
            }
        }

        it("makes the item link relative to the feed link in the event the item link has a nil scheme") {
            guard let feed = feed else { fail(); return }
            let item = Muon.Article(title: "article", link: NSURL(string: "/foo/bar/baz"), description: "", content: "", guid: "", published: nil, updated: nil, authors: [], enclosures: [])
            let info = Muon.Feed(title: "a &amp; title", link: NSURL(string: "https://example.com/qux")!, description: "description", articles: [item])
            let updateExpectation = spec.expectationWithDescription("Update Feed")
            dataService.updateFeed(feed, info: info) {
                updateExpectation.fulfill()
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
            let item = Muon.Article(title: "", link: nil, description: "", content: "", guid: "", published: nil, updated: nil, authors: [], enclosures: [])
            let info = Muon.Feed(title: "a title", link: NSURL(string: "https://example.com")!, description: "description", articles: [item])
            let updateExpectation = spec.expectationWithDescription("Update Feed")
            dataService.updateFeed(feed, info: info) {
                updateExpectation.fulfill()
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

            let item = Muon.Article(title: "article", link: nil, description: "", content: "", guid: "", published: nil, updated: nil, authors: [], enclosures: [])
            let existingItem = Muon.Article(title: existingArticle.title, link: existingArticle.link, description: existingArticle.summary, content: existingArticle.content, guid: "", published: existingArticle.published, updated: nil, authors: [], enclosures: [])
            let info = Muon.Feed(title: "a title", link: NSURL(string: "https://example.com")!, description: "description", articles: [item, existingItem])
            let updateExpectation = spec.expectationWithDescription("Update Feed")
            dataService.updateFeed(feed, info: info) {
                expect(feed.title) == "a title"
                expect(feed.summary) == "description"
                expect(feed.url).to(beNil())
                expect(feed.articlesArray.count).to(equal(2))
                if let firstArticle = feed.articlesArray.first {
                    expect(firstArticle) == existingArticle
                }
                if let secondArticle = feed.articlesArray.last {
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
                dataService.deleteArticle(article) {
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

            let item = Muon.Article(title: "a <p></p>&amp; title", link: NSURL(string: "https://example.com/foo/baz"), description: "description", content: content, guid: "guid", published: NSDate(timeIntervalSince1970: 10), updated: NSDate(timeIntervalSince1970: 15), authors: [], enclosures: [])

            let updateExpectation = spec.expectationWithDescription("Update Article")
            dataService.updateArticle(article!, item: item, feedURL: NSURL(string: "https://example.com/")!) { _ in
                expect(article!.relatedArticles).to(contain(otherArticle!))
                updateExpectation.fulfill()
            }
            spec.waitForExpectationsWithTimeout(1, handler: nil)
        }

        it("easily allows an article to be updated, filtering out title information") {
            guard let article = article else { fail(); return }
            let author = Muon.Author(name: "Rachel Brindle", email: NSURL(string: "mailto:rachel@example.com"), uri: NSURL(string: "https://example.com/rachel"))
            let content = (0..<100).map({_ in "<p>this was a content space</p>"}).reduce("", combine: +)

            let muonEnclosure = Muon.Enclosure(url: NSURL(string: "https://example.com/enclosure.mp3")!, length: 0, type: "audio/mpeg")
            let item = Muon.Article(title: "a <p></p>&amp; title", link: NSURL(string: "https://example.com"), description: "description", content: content, guid: "guid", published: NSDate(timeIntervalSince1970: 10), updated: NSDate(timeIntervalSince1970: 15), authors: [author], enclosures: [muonEnclosure])

            let updateExpectation = spec.expectationWithDescription("Update Article")
            if let searchIndex = dataService.searchIndex as? FakeSearchIndex {
                searchIndex.lastItemsAdded = []
            }
            dataService.updateArticle(article, item: item, feedURL: NSURL(string: "https://example.com/foo/bar/baz")!) { _ in
                expect(article.title) == "a & title"
                expect(article.link) == NSURL(string: "https://example.com")
                expect(article.published) == NSDate(timeIntervalSince1970: 10)
                expect(article.updatedAt) == NSDate(timeIntervalSince1970: 15)
                expect(article.summary) == "description"
                expect(article.content) == content
                expect(article.author) == "Rachel Brindle <rachel@example.com>"
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
            let muonEnclosure = Muon.Enclosure(url: NSURL(string: "https://example.com")!, length: 10, type: "html")
            var enclosure: rNewsKit.Enclosure?

            afterEach {
                if let enclosure = enclosure {
                    let deleteExpectation = spec.expectationWithDescription("Delete Enclosure")
                    dataService.deleteEnclosure(enclosure) {
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
                    dataService.upsertEnclosureForArticle(article, fromItem: muonEnclosure)

                    expect(article.enclosuresArray.count) == 1
                }
            }

            context("when the given article does not have an existing enclosure object matching the given one") {
                it("creates a new enclosure and inserts that into the article") {
                    guard let article = article else { fail(); return; }
                    dataService.upsertEnclosureForArticle(article, fromItem: muonEnclosure)

                    let findExpectation = spec.expectationWithDescription("Find Enclosure")

                    dataService.articlesMatchingPredicate(NSPredicate(value: true)) { articles in
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


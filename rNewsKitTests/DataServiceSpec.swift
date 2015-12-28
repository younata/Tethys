import Quick
import Nimble
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

        it("easily allows a feed to be updated") {
            guard let feed = feed else { fail(); return }
            let info = Muon.Feed(title: "a title", link: NSURL(string: "https://google.com")!, description: "description", articles: [])
            let updateExpectation = spec.expectationWithDescription("Update Feed")
            dataService.updateFeed(feed, info: info) {
                expect(feed.title) == "a title"
                expect(feed.summary) == "description"
                expect(feed.url).to(beNil())
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

        it("easily allows an article to be updated") {
            guard let article = article else { fail(); return }
            let author = Muon.Author(name: "Rachel Brindle", email: NSURL(string: "mailto:rachel@example.com"), uri: NSURL(string: "https://example.com/rachel"))
            let item = Muon.Article(title: "a title", link: NSURL(string: "https://example.com"), description: "description", content: "content", guid: "guid", published: NSDate(timeIntervalSince1970: 10), updated: NSDate(timeIntervalSince1970: 15), authors: [author], enclosures: [])

            let updateExpectation = spec.expectationWithDescription("Update Article")
            dataService.updateArticle(article, item: item) {
                expect(article.title) == "a title"
                expect(article.link) == NSURL(string: "https://example.com")
                expect(article.published) == NSDate(timeIntervalSince1970: 10)
                expect(article.updatedAt) == NSDate(timeIntervalSince1970: 15)
                expect(article.summary) == "description"
                expect(article.content) == "content"
                expect(article.author) == "Rachel Brindle <rachel@example.com>"
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
                    let updateExpectation = spec.expectationWithDescription("Update Enclosure")
                    dataService.upsertEnclosureForArticle(article, fromItem: muonEnclosure) {
                        expect($0) == enclosure
                        updateExpectation.fulfill()
                    }

                    spec.waitForExpectationsWithTimeout(1, handler: nil)

                    expect(article.enclosuresArray.count) == 1
                }
            }

            context("when the given article does not have an existing enclosure object matching the given one") {
                it("creates a new enclosure and inserts that into the article") {
                    guard let article = article else { fail(); return; }
                    let updateExpectation = spec.expectationWithDescription("Update Enclosure")
                    dataService.upsertEnclosureForArticle(article, fromItem: muonEnclosure) {
                        enclosure = $0
                        updateExpectation.fulfill()
                    }

                    spec.waitForExpectationsWithTimeout(1, handler: nil)

                    let findExpectation = spec.expectationWithDescription("Find Enclosure")

                    dataService.articlesMatchingPredicate(NSPredicate(format: "self == %@", article.articleID!)) { articles in
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


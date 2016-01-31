import Quick
import Nimble
@testable import rNewsKit

class DatabaseMigratorSpec: QuickSpec {
    override func spec() {
        var subject: DatabaseMigrator!

        let mainQueue = FakeOperationQueue()
        mainQueue.runSynchronously = true

        let oldFeed1 = Feed(title: "oldfeed1", url: NSURL(string: "https://example.com/feed1"), summary: "oldfeedsummary1", query: "", tags: ["a", "tag"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        let oldContent: String = (0..<100).map { _ in "there are five words "}
            .reduce(" there are five words ", combine: +)
        let oldArticle1 = Article(title: "oldarticle1", link: NSURL(string: "https://example.com/feed1/1"), summary: "old1Summary", author: "me1", published: NSDate(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident1", content: oldContent, read: true, estimatedReadingTime: 0, feed: oldFeed1, flags: ["hello", "there"], enclosures: [])
        oldFeed1.addArticle(oldArticle1)
        let oldEnclosure1 = Enclosure(url: NSURL(string: "https://example.com/feed1/1/enclosure1")!, kind: "text/text", article: oldArticle1)
        oldArticle1.addEnclosure(oldEnclosure1)

        let oldFeed2 = Feed(title: "oldfeed2", url: NSURL(string: "https://example.com/feed2"), summary: "oldfeedsummary2", query: "", tags: ["a", "tag", "2"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        let oldArticle2 = Article(title: "oldarticle2", link: NSURL(string: "https://example.com/feed2/2"), summary: "old2summary", author: "me2", published: NSDate(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident2", content: "content2", read: true, estimatedReadingTime: 20, feed: oldFeed2, flags: ["hello", "there"], enclosures: [])
        oldFeed2.addArticle(oldArticle2)
        let oldEnclosure2 = Enclosure(url: NSURL(string: "https://example.com/feed2/2/enclosure2")!, kind: "text/text", article: oldArticle2)
        oldArticle2.addEnclosure(oldEnclosure2)

        beforeEach {
            subject = DatabaseMigrator()

            mainQueue.reset()
            mainQueue.runSynchronously = true
        }

        describe("migrating from one database to another") {
            var oldDatabase: InMemoryDataService!
            var newDatabase: InMemoryDataService!

            var finishCount = 0

            beforeEach {
                oldDatabase = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())
                newDatabase = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())

                oldDatabase.feeds = [oldFeed1, oldFeed2]
                oldDatabase.articles = [oldArticle1, oldArticle2]
                oldDatabase.enclosures = [oldEnclosure1, oldEnclosure2]

                newDatabase.feeds = [oldFeed2]
                newDatabase.articles = [oldArticle2]
                newDatabase.enclosures = [oldEnclosure2]

                finishCount = 0
                subject.migrate(oldDatabase, to: newDatabase) {
                    finishCount += 1
                }
            }

            it("calls the callback when it's finished") {
                expect(finishCount) == 1
            }

            describe("migrating feeds") {
                it("migrates every feed over") {
                    expect(newDatabase.feeds).to(contain(oldFeed1))
                    expect(newDatabase.feeds).to(contain(oldFeed2))
                }

                it("does not duplicate feeds") {
                    expect(newDatabase.feeds.count) == 2
                }
            }

            describe("migrating articles") {
                it("migrates every article over") {
                    let changedArticle = Article(title: "oldarticle1", link: NSURL(string: "https://example.com/feed1/1"), summary: "old1Summary", author: "me1", published: NSDate(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident1", content: oldContent, read: true, estimatedReadingTime: 2, feed: oldFeed1, flags: ["hello", "there"], enclosures: [])

                    expect(newDatabase.articles).to(contain(changedArticle))
                    expect(newDatabase.articles).to(contain(oldArticle2))
                }

                it("updates the reading estimation if need be, even for existing articles") {
                    let changedArticle = Article(title: "oldarticle1", link: NSURL(string: "https://example.com/feed1/1"), summary: "old1Summary", author: "me1", published: NSDate(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident1", content: oldContent, read: true, estimatedReadingTime: 2, feed: oldFeed1, flags: ["hello", "there"], enclosures: [])

                    expect(newDatabase.articles).to(contain(changedArticle))
                    expect(newDatabase.articles).toNot(contain(oldArticle1))
                }

                it("does not duplicate articles") {
                    expect(newDatabase.articles.count) == 2
                }
            }

            describe("migrating enclosures") {
                it("migrates every enclosure over") {
                    expect(newDatabase.enclosures).to(contain(oldEnclosure1))
                    expect(newDatabase.enclosures).to(contain(oldEnclosure2))
                }

                it("does not duplicate enclosures") {
                    expect(newDatabase.enclosures.count) == 2
                }
            }
        }

        describe("deleting the contents of one database") {
            var database: InMemoryDataService!

            var finishCount = 0

            beforeEach {
                database = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())

                database.feeds = [oldFeed1, oldFeed2]
                database.articles = [oldArticle1, oldArticle2]
                database.enclosures = [oldEnclosure1, oldEnclosure2]

                finishCount = 0

                subject.deleteEverything(database) {
                    finishCount += 1
                }
            }

            it("calls finish once") {
                expect(finishCount) == 1
            }

            it("deletes all the feeds") {
                expect(database.feeds.count) == 0
            }

            it("deletes all the articles") {
                expect(database.articles.count) == 0
            }

            it("deletes all the enclosures") {
                expect(database.enclosures.count) == 0
            }
        }
    }
}

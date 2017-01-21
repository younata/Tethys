import Quick
import Nimble
@testable import TethysKit

class DatabaseMigratorSpec: QuickSpec {
    override func spec() {
        var subject: DatabaseMigrator!

        let mainQueue = FakeOperationQueue()
        mainQueue.runSynchronously = true

        beforeEach {
            subject = DatabaseMigrator()

            mainQueue.reset()
            mainQueue.runSynchronously = true
        }

        describe("migrating from one database to another") {
            var oldDatabase: InMemoryDataService!
            var newDatabase: InMemoryDataService!

            var finishCount = 0

            let oldFeed1 = Feed(title: "oldfeed1", url: URL(string: "https://example.com/feed1")!, summary: "oldfeedsummary1", tags: ["a", "tag"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            let oldContent: String = (0..<100).map { _ in "there are five words "}
                .reduce(" there are five words ", +)
            let oldArticle1 = Article(title: "oldarticle1", link: URL(string: "https://example.com/feed1/1")!, summary: "old1Summary", authors: [Author("me1")], published: Date(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident1", content: oldContent, read: true, synced: false, estimatedReadingTime: 0, feed: oldFeed1, flags: ["hello", "there"])
            oldFeed1.addArticle(oldArticle1)

            let oldFeed2 = Feed(title: "oldfeed2", url: URL(string: "https://example.com/feed2")!, summary: "oldfeedsummary2", tags: ["a", "tag", "2"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            let oldArticle2 = Article(title: "oldarticle2", link: URL(string: "https://example.com/feed2/2")!, summary: "old2summary", authors: [Author("me2")], published: Date(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident2", content: "content2", read: true, synced: false, estimatedReadingTime: 20, feed: oldFeed2, flags: ["hello", "there"])
            oldFeed2.addArticle(oldArticle2)

            var progressCalls: [Double] = []

            beforeEach {
                oldDatabase = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())
                newDatabase = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())

                oldDatabase.feeds = [oldFeed1, oldFeed2]
                oldDatabase.articles = [oldArticle1, oldArticle2]

                newDatabase.feeds = [oldFeed2]
                newDatabase.articles = [oldArticle2]

                finishCount = 0
                progressCalls = []
                subject.migrate(oldDatabase, to: newDatabase, progress: { progressCalls.append($0) }) {
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
                    let changedArticle = Article(title: "oldarticle1", link: URL(string: "https://example.com/feed1/1")!, summary: "old1Summary", authors: [Author("me1")], published: Date(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident1", content: oldContent, read: true, synced: false, estimatedReadingTime: 2, feed: oldFeed1, flags: ["hello", "there"])

                    expect(newDatabase.articles).to(contain(changedArticle))
                    expect(newDatabase.articles).to(contain(oldArticle2))
                }

                it("updates the reading estimation if need be, even for existing articles") {
                    let changedArticle = Article(title: "oldarticle1", link: URL(string: "https://example.com/feed1/1")!, summary: "old1Summary", authors: [Author("me1")], published: Date(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident1", content: oldContent, read: true, synced: false, estimatedReadingTime: 2, feed: oldFeed1, flags: ["hello", "there"])

                    expect(newDatabase.articles).to(contain(changedArticle))
                    expect(newDatabase.articles).toNot(contain(oldArticle1))
                }

                it("does not duplicate articles") {
                    expect(newDatabase.articles.count) == 2
                }
            }
        }

        describe("deleting the contents of one database") {
            var database: InMemoryDataService!

            var finishCount = 0
            var progressCalls: [Double] = []

            beforeEach {
                database = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())

                let oldFeed1 = Feed(title: "oldfeed1", url: URL(string: "https://example.com/feed1")!, summary: "oldfeedsummary1", tags: ["a", "tag"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let oldContent: String = (0..<100).map { _ in "there are five words "}
                    .reduce(" there are five words ", +)
                let oldArticle1 = Article(title: "oldarticle1", link: URL(string: "https://example.com/feed1/1")!, summary: "old1Summary", authors: [Author("me1")], published: Date(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident1", content: oldContent, read: true, synced: false, estimatedReadingTime: 0, feed: oldFeed1, flags: ["hello", "there"])
                oldFeed1.addArticle(oldArticle1)

                let oldFeed2 = Feed(title: "oldfeed2", url: URL(string: "https://example.com/feed2")!, summary: "oldfeedsummary2", tags: ["a", "tag", "2"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let oldArticle2 = Article(title: "oldarticle2", link: URL(string: "https://example.com/feed2/2")!, summary: "old2summary", authors: [Author("me2")], published: Date(timeIntervalSince1970: 1), updatedAt: nil, identifier: "ident2", content: "content2", read: true, synced: false, estimatedReadingTime: 20, feed: oldFeed2, flags: ["hello", "there"])
                oldFeed2.addArticle(oldArticle2)

                database.feeds = [oldFeed1, oldFeed2]
                database.articles = [oldArticle1, oldArticle2]

                finishCount = 0
                progressCalls = []

                subject.deleteEverything(database, progress: { progressCalls.append($0) }) {
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
        }
    }
}

import Quick
import Nimble
import Ra
import rNews

class DataManagerSpec: QuickSpec {
    override func spec() {
        var subject : DataManager! = nil
        var injector : Ra.Injector! = nil

        var moc : NSManagedObjectContext! = nil

        var backgroundQueue : FakeOperationQueue! = nil
        var mainQueue : FakeOperationQueue! = nil

        var feeds : [Feed] = []
        var feed1 : CoreDataFeed! = nil
        var feed2 : CoreDataFeed! = nil
        var feed3 : CoreDataFeed! = nil

        beforeEach {
            moc = managedObjectContext()

            backgroundQueue = FakeOperationQueue()
            mainQueue = FakeOperationQueue()
            for queue in [backgroundQueue, mainQueue] {
                queue.runSynchronously = true
            }
            injector = Ra.Injector()
            injector.bind(kBackgroundQueue, to: backgroundQueue)
            injector.bind(kMainQueue, to: mainQueue)

            subject = injector.create(DataManager.self) as! DataManager
            subject.backgroundObjectContext = moc

            // seed with a few feeds/articles/enclosures

            feed1 = createFeed(moc)
            feed1.title = "a"
            feed1.tags = ["a", "b", "c"]
            let b = createArticle(moc)
            b.title = "b"
            let c = createArticle(moc)
            c.title = "c"
            c.read = true
            feed1.addArticlesObject(b)
            feed1.addArticlesObject(c)
            b.feed = feed1
            c.feed = feed1
            feed2 = createFeed(moc)
            feed2.title = "d"
            feed2.tags = ["b", "d"]
            feed3 = createFeed(moc)
            feed3.title = "e"
            feed3.tags = ["dad"]
            moc.save(nil)

            feeds = map([feed1, feed2, feed3]) { Feed(feed: $0) }
        }

        describe("allTags") {
            it("should return a list of all tags used") {
                expect(subject.allTags()).to(equal(["a", "b", "c", "d", "dad"]))
            }
        }

        describe("feeds") {
            it("should return a list of all feeds") {
                expect(subject.feeds()).to(equal(feeds))
            }
        }

        describe("feedsMatchingTag") {
            it("should return all the feeds when no tag, or empty string is given as the tag") {
                expect(subject.feedsMatchingTag(nil)).to(equal(feeds))
                expect(subject.feedsMatchingTag("")).to(equal(feeds))
            }

            it("should return feeds that partially match a tag") {
                let subFeeds = map([feed1, feed3]) { Feed(feed: $0) }
                expect(subject.feedsMatchingTag("a")).to(equal(subFeeds))
            }
        }
    }
}

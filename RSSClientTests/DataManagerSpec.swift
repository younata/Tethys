import Quick
import Nimble
import Ra

class DataManagerSpec: QuickSpec {
    override func spec() {
        var subject : DataManager! = nil
        var injector : Ra.Injector! = nil

        var moc : NSManagedObjectContext! = nil

        var backgroundQueue : FakeOperationQueue! = nil
        var mainQueue : FakeOperationQueue! = nil

        var feeds : [Feed] = []

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

            let a = createFeed(moc)
            a.title = "a"
            a.tags = ["a", "b", "c"]
            let b = createArticle(moc)
            b.title = "b"
            let c = createArticle(moc)
            c.title = "c"
            c.read = true
            a.addArticlesObject(b)
            a.addArticlesObject(c)
            b.feed = a
            c.feed = a
            let d = createFeed(moc)
            d.title = "d"
            d.tags = ["a", "d"]
            moc.save(nil)

            feeds = map([a, d]) { Feed(feed: $0) }
        }

        describe("allTags") {
            it("should return a list of all tags used") {
                expect(subject.allTags()).to(equal(["a", "b", "c", "d"]))
            }
        }

        describe("feeds") {
            it("should return a list of all feeds") {
                expect(subject.feeds()).to(equal(feeds))
            }
        }
    }
}

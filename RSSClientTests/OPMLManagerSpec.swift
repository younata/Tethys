import Quick
import Nimble
import rNews

class OPMLManagerSpec: QuickSpec {
    override func spec() {
        var subject : OPMLManager! = nil

        var moc : NSManagedObjectContext! = nil

        var dataManager : DataManagerMock! = nil
        var importQueue : FakeOperationQueue! = nil
        var mainQueue : FakeOperationQueue! = nil

        beforeEach {
            dataManager = DataManagerMock()
            importQueue = FakeOperationQueue()
            importQueue.runSynchronously = true
            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            subject = OPMLManager(dataManager: dataManager, mainQueue: mainQueue, importQueue: importQueue)

            moc = managedObjectContext()
        }

        describe("Importing OPML Files") {
            var feeds : [Feed] = []
            beforeEach {
                let opmlUrl = NSBundle(forClass: self.classForCoder).URLForResource("test", withExtension: "opml")!

                subject.importOPML(opmlUrl) {otherFeeds in
                    feeds = otherFeeds
                }

                expect(feeds.count).toEventuallyNot(beNil(), timeout: 5)
            }

            it("should return a list of feeds imported") {
                expect(feeds.count).to(equal(3))
                if (feeds.count != 3) {
                    return;
                }
                feeds.sortInPlace { $0.title < $1.title }
                let first = feeds[0]
                expect(first.url).to(equal(NSURL(string: "http://example.com/feedWithTag")))

                let second = feeds[1]
                expect(second.url).to(equal(NSURL(string: "http://example.com/feedWithTitle")))

                let query = feeds[2]
                expect(query.title).to(equal("Query Feed"))
                expect(query.url).to(beNil())
                expect(query.query).to(equal("return true;"))
            }
        }

        describe("Writing OPML Files") {

            var feed1 : Feed! = nil
            var feed2 : Feed! = nil
            var feed3 : Feed! = nil

            beforeEach {
                feed1 = Feed(title: "a", url: NSURL(string: "http://example.com/feed"), summary: "", query: nil,
                    tags: ["a", "b", "c"], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
                feed2 = Feed(title: "d", url: nil, summary: "", query: "", tags: [],
                    waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
                feed3 = Feed(title: "e", url: NSURL(string: "http://example.com/otherfeed"), summary: "", query: nil,
                    tags: ["dad"], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)

                dataManager.feedsList = [feed1, feed2, feed3]

                subject.writeOPML()
            }

            it("should write an OPML file to ~/Documents/rnews.opml") {
                let fileManager = NSFileManager.defaultManager()
                let file = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
                expect(fileManager.fileExistsAtPath(file)).to(beTruthy())

                let text = try! String(contentsOfFile: file, encoding: NSUTF8StringEncoding)

                let parser = OPMLParser(text: text)

                var testItems: [OPMLItem] = []

                parser.success {items in
                    testItems = items
                    expect(items.count).to(equal(2))
                    if (items.count != 2) {
                        return
                    }
                    let a = items[0]
                    expect(a.title).to(equal("a"))
                    expect(a.tags).to(equal(["a", "b", "c"]))
                    let c = items[1]
                    expect(c.title).to(equal("e"))
                    expect(c.tags).to(equal(["dad"]))
                }

                parser.main()

                expect(testItems.count).toEventuallyNot(equal(0))
            }
        }
    }
}

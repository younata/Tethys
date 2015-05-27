import Quick
import Nimble

class OPMLManagerSpec: QuickSpec {
    override func spec() {
        var subject : OPMLManager! = nil

        var moc : NSManagedObjectContext! = nil

        var dataManager : DataManagerMock! = nil

        beforeEach {
            dataManager = DataManagerMock()
            subject = OPMLManager(dataManager: dataManager)

            moc = managedObjectContext()
        }

        describe("Importing OPML Files") {
            var feeds : [Feed] = []
            beforeEach {
                // write the opml file

                let expectation = self.expectationWithDescription("import opml")

                let opmlUrl = NSURL(string: "")!

                subject.importOPML(opmlUrl, progress: { _ in

                }) {otherFeeds in
                    feeds = otherFeeds
                    expectation.fulfill()
                }

                self.waitForExpectationsWithTimeout(1) {error in
                    expect(error).to(beNil())
                }
            }

            it("should import the OPML file") {
                // no idea.
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

                let text = String(contentsOfFile: file, encoding: NSUTF8StringEncoding, error: nil)!

                let parser = OPMLParser(text: text)

                let expectation = self.expectationWithDescription("opml parsing")

                parser.success {items in
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

                    expectation.fulfill()
                }

                parser.main()

                self.waitForExpectationsWithTimeout(1) {error in
                    expect(error).to(beNil())
                }
            }
        }
    }
}

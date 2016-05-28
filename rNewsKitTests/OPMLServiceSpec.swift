import Quick
import Nimble
import CoreData
import Ra
import Lepton
@testable import rNewsKit

class OPMLServiceSpec: QuickSpec {
    override func spec() {
        var subject: OPMLService!

        var dataRepository: FakeDefaultDatabaseUseCase!
        var importQueue: FakeOperationQueue!
        var mainQueue: FakeOperationQueue!

        var dataServiceFactory: FakeDataServiceFactory!
        var dataService: InMemoryDataService!

        beforeEach {
            importQueue = FakeOperationQueue()
            importQueue.runSynchronously = true

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            dataService = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())

            dataServiceFactory = FakeDataServiceFactory()
            dataServiceFactory.currentDataService = dataService

            dataRepository = FakeDefaultDatabaseUseCase(
                mainQueue: mainQueue,
                reachable: nil,
                dataServiceFactory: dataServiceFactory,
                updateService: FakeUpdateService(),
                databaseMigrator: FakeDatabaseMigrator(),
                scriptService: JavaScriptService()
            )

            let injector = Injector()
            injector.bind(kMainQueue, toInstance: mainQueue)
            injector.bind(kBackgroundQueue, toInstance: importQueue)
            injector.bind(DefaultDatabaseUseCase.self, toInstance: dataRepository)
            injector.bind(DataService.self, toInstance: dataService)

            subject = OPMLService(injector: injector)
        }

        describe("Importing OPML Files") {
            var feeds: [Feed] = []
            beforeEach {
                let opmlUrl = NSBundle(forClass: self.classForCoder).URLForResource("test", withExtension: "opml")!

                subject.importOPML(opmlUrl) {otherFeeds in
                    feeds = otherFeeds
                }
            }

            it("makes a request to the datarepository for the list of all feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds promise succeeds") {
                beforeEach {
                    let previouslyImportedFeed = Feed(title: "imported",
                        url: NSURL(string: "http://example.com/previouslyImportedFeed"), summary: "", query: nil,
                        tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    dataRepository.feedsPromises.first?.resolve(.Success([previouslyImportedFeed]))
                }

                it("should return a list of feeds imported") {
                    expect(feeds.count).to(equal(3))
                    guard feeds.count == 3 else {
                        return
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

            context("when the feeds promise fails") {
                // TODO: Implement case when feeds promise fails
            }
        }

        describe("Writing OPML Files") {
            beforeEach {
                subject.writeOPML()
            }

            afterEach {
                let fileManager = NSFileManager.defaultManager()
                let file = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
                let _ = try? fileManager.removeItemAtPath(file)
            }

            it("makes a request to the datarepository for the list of all feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds promise succeeds") {
                beforeEach {
                    let feed1 = Feed(title: "a", url: NSURL(string: "http://example.com/feed"), summary: "", query: nil,
                        tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed2 = Feed(title: "d", url: nil, summary: "", query: "", tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed3 = Feed(title: "e", url: NSURL(string: "http://example.com/otherfeed"), summary: "", query: nil,
                        tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    dataRepository.feedsPromises.first?.resolve(.Success([feed1, feed2, feed3]))
                }

                it("should write an OPML file to ~/Documents/rnews.opml") {
                    let fileManager = NSFileManager.defaultManager()
                    let file = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
                    expect(fileManager.fileExistsAtPath(file)) == true

                    let text = (try? String(contentsOfFile: file, encoding: NSUTF8StringEncoding)) ?? ""

                    let parser = Lepton.Parser(text: text)

                    var testItems: [Lepton.Item] = []

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
                    
                    expect(testItems).toNot(beEmpty())
                }
            }

            context("when the feeds promise fails") {
                // TODO: Implement case when feeds promise fails
            }
        }

        describe("When feeds change") {
            beforeEach {
                let feed1 = Feed(title: "a", url: NSURL(string: "http://example.com/feed"), summary: "", query: nil,
                    tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let feed2 = Feed(title: "d", url: nil, summary: "", query: "", tags: [],
                    waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                let feed3 = Feed(title: "e", url: NSURL(string: "http://example.com/otherfeed"), summary: "", query: nil,
                    tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                let feeds = [feed1, feed2, feed3]

                for subscriber in dataRepository.subscribers {
                    subscriber.didUpdateFeeds([])
                }
            }

            afterEach {
                let fileManager = NSFileManager.defaultManager()
                let file = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
                let _ = try? fileManager.removeItemAtPath(file)
            }

            it("makes a request to the datarepository for the list of all feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds promise succeeds") {
                beforeEach {
                    let feed1 = Feed(title: "a", url: NSURL(string: "http://example.com/feed"), summary: "", query: nil,
                        tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed2 = Feed(title: "d", url: nil, summary: "", query: "", tags: [],
                        waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feed3 = Feed(title: "e", url: NSURL(string: "http://example.com/otherfeed"), summary: "", query: nil,
                        tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    dataRepository.feedsPromises.first?.resolve(.Success([feed1, feed2, feed3]))
                }

                it("should write an OPML file to ~/Documents/rnews.opml") {
                    let fileManager = NSFileManager.defaultManager()
                    let file = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
                    expect(fileManager.fileExistsAtPath(file)) == true

                    guard let text = try? String(contentsOfFile: file, encoding: NSUTF8StringEncoding) else { return }

                    let parser = Lepton.Parser(text: text)

                    var testItems: [Lepton.Item] = []

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
                    
                    expect(testItems).toNot(beEmpty())
                }
            }

            context("when the feeds promise fails") {
                beforeEach {
                    dataRepository.feedsPromises.first?.resolve(.Failure(.Unknown))
                }

                it("doesn't write anything to disk") {
                    let fileManager = NSFileManager.defaultManager()
                    let file = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
                    expect(fileManager.fileExistsAtPath(file)) == false
                }
            }
        }
    }
}

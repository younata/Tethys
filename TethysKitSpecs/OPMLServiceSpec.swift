import Quick
import Nimble
import Lepton
import CBGPromise
import Result
@testable import TethysKit

class DefaultOPMLServiceSpec: QuickSpec {
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
                updateUseCase: FakeUpdateUseCase()
            )

            subject = DefaultOPMLService(
                dataRepository: dataRepository,
                mainQueue: mainQueue,
                importQueue: importQueue
            )
        }

        describe("Importing OPML Files") {
            var feeds: [Feed] = []
            beforeEach {
                let opmlUrl = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "opml")!

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
                        url: URL(string: "http://example.com/previouslyImportedFeed")!, summary: "",
                        tags: [], articles: [], image: nil)
                    dataRepository.feedsPromises.first?.resolve(.success([previouslyImportedFeed]))
                }

                it("tells the data repository to update the feeds") {
                    expect(dataRepository.didUpdateFeeds) == true
                }

                describe("when the data repository finishes") {
                    beforeEach {
                        dataRepository.updateFeedsCompletion(dataService.feeds, [])
                    }

                    it("returns a list of feeds imported") {
                        expect(feeds.count).to(equal(2))
                        guard feeds.count == 2 else {
                            return
                        }
                        feeds.sort { $0.title < $1.title }
                        let first = feeds[0]
                        expect(first.url).to(equal(URL(string: "http://example.com/feedWithTag")))

                        let second = feeds[1]
                        expect(second.url).to(equal(URL(string: "http://example.com/feedWithTitle")))
                    }
                }
            }

            context("when the feeds promise fails") {
                // TODO: Implement case when feeds promise fails
            }
        }

        describe("Writing OPML files") {
            var writeOPMLFuture: Future<Result<URL, TethysError>>!

            beforeEach {
                writeOPMLFuture = subject.writeOPML()
            }

            afterEach {
                let fileManager = FileManager.default
                let file = documentsDirectory() + "/Tethys.opml"
                let _ = try? fileManager.removeItem(atPath: file)
            }

            it("makes a request to the datarepository for the list of all feeds") {
                expect(dataRepository.feedsPromises.count) == 1
            }

            context("when the feeds promise succeeds") {
                beforeEach {
                    let feed1 = Feed(title: "a", url: URL(string: "http://example.com/feed")!, summary: "",
                        tags: ["a", "b", "c"], articles: [], image: nil)
                    let feed3 = Feed(title: "e", url: URL(string: "http://example.com/otherfeed")!, summary: "",
                        tags: ["dad"], articles: [], image: nil)
                    dataRepository.feedsPromises.first?.resolve(.success([feed1, feed3]))
                }

                it("resolves the promise with a valid opml file") {
                    expect(writeOPMLFuture.value?.value).toNot(beNil())

                    guard let url = writeOPMLFuture.value?.value, let text = try? String(contentsOf: url) else { return }

                    let parser = Lepton.Parser(text: text)

                    var testItems: [Lepton.Item] = []

                    _ = parser.success {items in
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
                it("forwards the promise as the error") {
                    dataRepository.feedsPromises.first?.resolve(.failure(.unknown))

                    expect(writeOPMLFuture.value?.error) == TethysError.unknown
                }
            }
        }
    }
}

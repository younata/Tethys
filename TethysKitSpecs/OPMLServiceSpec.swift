import Quick
import Nimble
import Lepton
import Result
import CBGPromise
@testable import TethysKit

class LeptonOPMLServiceSpec: QuickSpec {
    override func spec() {
        var subject: OPMLService!

        var feedService: FakeFeedService!
        var workQueue: FakeOperationQueue!
        var mainQueue: FakeOperationQueue!

        beforeEach {
            feedService = FakeFeedService()

            workQueue = FakeOperationQueue()
            workQueue.runSynchronously = true

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            subject = LeptonOPMLService(
                feedService: feedService,
                mainQueue: mainQueue,
                importQueue: workQueue
            )
        }

        describe("importOPML()") {
            var future: Future<Result<AnyCollection<Feed>, TethysError>>!
            beforeEach {
                let opmlUrl = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "opml")!

                future = subject.importOPML(opmlUrl)
            }

            it("tells the feed service to import each feed in the opml file") {
                expect(feedService.subscribeCalls).to(haveCount(3))

                expect(feedService.subscribeCalls).to(contain(
                    URL(string: "http://example.com/feedWithTag")!,
                    URL(string: "http://example.com/previouslyImportedFeed")!,
                    URL(string: "http://example.com/feedWithTitle")!
                ))
            }

            describe("if all the subscribe calls succeed") {
                let feed1 = Feed(title: "a", url: URL(string: "http://example.com/feed1")!, summary: "", tags: [])
                let feed2 = Feed(title: "b", url: URL(string: "http://example.com/feed2")!, summary: "", tags: [])
                let feed3 = Feed(title: "c", url: URL(string: "http://example.com/feed3")!, summary: "", tags: [])

                beforeEach {
                    guard feedService.subscribeCalls.count == 3 else { return }
                    feedService.subscribePromises[0].resolve(.success(feed1))
                    feedService.subscribePromises[1].resolve(.success(feed2))
                    feedService.subscribePromises[2].resolve(.success(feed3))
                }

                it("resolves the future with the collection of feeds") {
                    expect(future.value?.value).to(haveCount(3))
                    expect(future.value?.value).to(contain(feed1, feed2, feed3))
                }
            }

            describe("if only a handful of subscribe calls succeed") {
                let feed1 = Feed(title: "a", url: URL(string: "http://example.com/feed1")!, summary: "", tags: [])
                let feed3 = Feed(title: "c", url: URL(string: "http://example.com/feed3")!, summary: "", tags: [])

                beforeEach {
                    guard feedService.subscribeCalls.count == 3 else { return }
                    feedService.subscribePromises[0].resolve(.success(feed1))
                    feedService.subscribePromises[1].resolve(.failure(.unknown))
                    feedService.subscribePromises[2].resolve(.success(feed3))
                }

                it("resolves the future with the collection of successful feeds") {
                    expect(future.value?.value).to(haveCount(2))
                    expect(future.value?.value).to(contain(feed1, feed3))
                }
            }

            describe("if none of the subscribe calls succeed") {
                beforeEach {
                    guard feedService.subscribeCalls.count == 3 else { return }
                    feedService.subscribePromises[0].resolve(.failure(.database(.unknown)))
                    feedService.subscribePromises[1].resolve(.failure(.unknown))
                    feedService.subscribePromises[2].resolve(.failure(.http(503)))
                }

                it("resolves the future noting each error") {
                    expect(future.value?.error).to(equal(TethysError.multiple([
                        TethysError.database(.unknown),
                        TethysError.unknown,
                        TethysError.http(503)
                    ])))
                }
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

            it("asks the feed service for the list of all feeds") {
                expect(feedService.feedsPromises.count) == 1
            }

            context("when the feeds promise succeeds") {
                beforeEach {
                    let feed1 = Feed(title: "a", url: URL(string: "http://example.com/feed")!, summary: "",
                                     tags: ["a", "b", "c"], unreadCount: 0, image: nil)
                    let feed3 = Feed(title: "e", url: URL(string: "http://example.com/otherfeed")!, summary: "",
                                     tags: ["dad"], unreadCount: 0, image: nil)
                    feedService.feedsPromises.last?.resolve(.success(AnyCollection([feed1, feed3])))
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
                    feedService.feedsPromises.last?.resolve(.failure(.unknown))

                    expect(writeOPMLFuture.value?.error) == TethysError.unknown
                }
            }
        }
    }
}

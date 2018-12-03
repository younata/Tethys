import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP

@testable import TethysKit

class ImportUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultImportUseCase!
        var httpClient: FakeHTTPClient!
        var feedService: FakeFeedService!
        var opmlService: FakeOPMLService!
        var fileManager: FakeFileManager!
        var mainQueue: FakeOperationQueue!

        beforeEach {
            opmlService = FakeOPMLService()
            fileManager = FakeFileManager()

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            httpClient = FakeHTTPClient()
            feedService = FakeFeedService()

            subject = DefaultImportUseCase(
                httpClient: httpClient,
                feedService: feedService,
                opmlService: opmlService,
                fileManager: fileManager,
                mainQueue: mainQueue
            )
        }

        func itBehavesLikeSubscribingToAFeed(url: URL, future: @escaping () -> Future<Result<Void, TethysError>>) {
            describe("subscribing to a feed") {
                it("asks the feed service to subscribe to the feed at that url") {
                    expect(feedService.subscribeCalls).to(haveCount(1))
                    expect(feedService.subscribeCalls.last).to(equal(url))
                }

                describe("when the feed service succeeds") {
                    beforeEach {
                        feedService.subscribePromises.last?.resolve(.success(
                            Feed(title: "", url: url, summary: "", tags: [])
                            ))
                    }

                    it("resolves the promise with .success") {
                        expect(future().value?.value).to(beVoid())
                    }
                }

                describe("when the feed service fails") {
                    beforeEach {
                        feedService.subscribePromises.last?.resolve(.failure(.database(.unknown)))
                    }

                    it("forwards the error") {
                        expect(future().value?.error).to(equal(.database(.unknown)))
                    }
                }
            }
        }

        describe("-scanForImportable:progress:callback:") {
            var receivedItem: ImportUseCaseItem?

            beforeEach {
                receivedItem = nil
            }

            context("when asked to scan a network URL") {
                let url = URL(string: "https://example.com/item")!


                beforeEach {
                    _ = subject.scanForImportable(url).then {
                        receivedItem = $0
                    }
                }

                it("makes a call to the network for the item") {
                    expect(httpClient.requests).to(haveCount(1))
                    expect(httpClient.requests.last?.url).to(equal(url))
                }

                context("when the network returns a feed file") {
                    let feedURL = Bundle(for: self.classForCoder).url(forResource: "feed", withExtension: "rss")!
                    let feedData = try! Data(contentsOf: feedURL)

                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: feedData,
                            status: .ok,
                            mimeType: "",
                            headers: [:]
                        )))
                    }

                    it("calls the callback with .Feed, the URL and the number of articles found") {
                        expect(receivedItem) == ImportUseCaseItem.feed(url, 10)
                    }

                    context("later calling -importItem:callback: with that url") {
                        var future: Future<Result<Void, TethysError>>!

                        beforeEach {
                            future = subject.importItem(url)
                        }

                        it("does not make another urlSession call") {
                            expect(httpClient.requests).to(haveCount(1))
                        }

                        itBehavesLikeSubscribingToAFeed(url: url) { return future }
                    }
                }

                context("when the network returns an OPML file") {
                    let opmlURL = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "opml")!
                    let opmlData = try! Data(contentsOf: opmlURL)

                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: opmlData,
                            status: .ok,
                            mimeType: "",
                            headers: [:]
                        )))
                    }

                    it("calls the callback with .OPML and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.opml(url, 4)
                    }

                    context("later calling -importItem:callback: with that url") {
                        var future: Future<Result<Void, TethysError>>!

                        beforeEach {
                            future = subject.importItem(url)
                        }

                        it("does not make another network call") {
                            expect(httpClient.requests).to(haveCount(1))
                        }

                        it("asks the opml service to import the feed list") {
                            expect(opmlService.importOPMLURL) == url
                        }

                        it("calls the callback when the opml service finishes") {
                            opmlService.importOPMLCompletion([])

                            expect(future.value?.value).to(beVoid())
                        }
                    }
                }

                context("when the network returns a standard web page") {
                    let feed1html = "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS\" href=\"/feed.xml\">"
                    let feed1Url = URL(string: "/feed.xml", relativeTo: url)!.absoluteURL
                    let feed2html = "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS\" href=\"/feed2.xml\">"
                    let feed2Url = URL(string: "/feed2.xml", relativeTo: url)!.absoluteURL

                    let webPageString = "<html><head>\(feed1html)\(feed2html)</head><body></body></html>"
                    let webPageData = webPageString.data(using: String.Encoding.utf8)!

                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: webPageData,
                            status: .ok,
                            mimeType: "",
                            headers: [:]
                        )))
                    }

                    it("calls the callback with the url and the list of found feed urls") {
                        expect(receivedItem) == ImportUseCaseItem.webPage(url, [feed1Url, feed2Url])
                    }

                    context("later calling -importItem:callback: with one of the found feed urls") {
                        var future: Future<Result<Void, TethysError>>!

                        beforeEach {
                            future = subject.importItem(feed1Url)
                        }

                        it("does not make another urlSession call") {
                            expect(httpClient.requests).to(haveCount(1))
                        }

                        itBehavesLikeSubscribingToAFeed(url: feed1Url) { return future }
                    }
                }

                context("when the network returns an error") {
                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.failure(.unknown))
                    }

                    it("calls the callback with .None and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.none(url)
                    }
                }
            }

            context("when asked to scan a file system URL") {
                context("and that file is a feed file") {
                    let feedURL = Bundle(for: self.classForCoder).url(forResource: "feed", withExtension: "rss")!

                    beforeEach {
                        _ = subject.scanForImportable(feedURL).then {
                            receivedItem = $0
                        }
                    }

                    it("does not make a network call") {
                        expect(httpClient.requests).to(haveCount(0))
                    }

                    it("calls the callback with .Feed and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.feed(feedURL, 10)
                    }

                    context("later calling -importItem:callback: with that url") {
                        var future: Future<Result<Void, TethysError>>!

                        beforeEach {
                            future = subject.importItem(feedURL)
                        }

                        itBehavesLikeSubscribingToAFeed(url: URL(string: "https://younata.github.io/")!) { return future }
                    }
                }

                context("and that file is an opml file") {
                    let opmlURL = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "opml")!

                    beforeEach {
                        _ = subject.scanForImportable(opmlURL).then {
                            receivedItem = $0
                        }
                    }

                    it("does not call the network service") {
                        expect(httpClient.requests).to(haveCount(0))
                    }

                    it("calls the callback with .OPML and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.opml(opmlURL, 4)
                    }

                    context("later calling -importItem:callback: with that url") {
                        var didImport = false
                        beforeEach {
                            _ = subject.importItem(opmlURL).then { _ in
                                didImport = true
                            }
                        }

                        it("asks the opml service to import the feed list") {
                            expect(opmlService.importOPMLURL) == opmlURL
                        }

                        it("calls the callback when the opml service finishes") {
                            opmlService.importOPMLCompletion([])
                            
                            expect(didImport) == true
                        }
                    }
                }

                context("and that file is neither") {
                    let url = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "jpg")!

                    beforeEach {
                        _ = subject.scanForImportable(url).then {
                            receivedItem = $0
                        }
                    }

                    it("does not call the network service") {
                        expect(httpClient.requests).to(haveCount(0))
                    }

                    it("calls the callback with .None and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.none(url)
                    }
                }
            }
        }

        describe("-importItem:callback:") {
            let url = URL(string: "https://example.com/item")!

            it("informs the user that we don't have data for this url") {
                var didImport = false
                _ = subject.importItem(url).then { _ in
                    didImport = true
                }
                expect(didImport) == true
            }

            // other cases are covered up above
        }
    }
}

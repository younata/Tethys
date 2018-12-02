import Quick
import Nimble

import TethysKit

class ImportUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultImportUseCase!
        var urlSession: FakeURLSession!
        var feedRepository: FakeDatabaseUseCase!
        var opmlService: FakeOPMLService!
        var fileManager: FakeFileManager!
        var mainQueue: FakeOperationQueue!

        beforeEach {
            urlSession = FakeURLSession()
            feedRepository = FakeDatabaseUseCase()
            opmlService = FakeOPMLService()
            fileManager = FakeFileManager()

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            subject = DefaultImportUseCase(
                urlSession: urlSession,
                feedRepository: feedRepository,
                opmlService: opmlService,
                fileManager: fileManager,
                mainQueue: mainQueue
            )
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
                    expect(urlSession.lastURL) == url
                }

                context("when the network returns a feed file") {
                    let feedURL = Bundle(for: self.classForCoder).url(forResource: "feed", withExtension: "rss")!
                    let feedData = try? Data(contentsOf: feedURL)

                    beforeEach {
                        urlSession.lastCompletionHandler(feedData, nil, nil)
                    }

                    it("calls the callback with .Feed and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.feed(url, 100)
                    }

                    context("later calling -importItem:callback: with that url") {
                        var didImport = false
                        beforeEach {
                            urlSession.lastURL = nil
                            _ = subject.importItem(url).then { _ in
                                didImport = true
                            }
                        }

                        it("does not make another urlSession call") {
                            expect(urlSession.lastURL).to(beNil())
                        }

                        it("asks the feed repository for a list of all feeds") {
                            expect(feedRepository.feedsPromises.count) > 0
                        }

                        describe("when the feed repository succeeds") {
                            context("and a feed with the proposed feed url is in the feeds list") {
                                beforeEach {
                                    let existingFeed = Feed(title: "", url: url, summary: "", tags: [], articles: [], image: nil)

                                    feedRepository.feedsPromises.first?.resolve(.success([existingFeed]))
                                }

                                it("does not ask the feed repository to import the feed") {
                                    expect(feedRepository.didCreateFeed) == false
                                }

                                it("calls the callback") {
                                    expect(didImport) == true
                                }
                            }

                            context("and a feed with the proposed feed url is not in the feeds list") {
                                beforeEach {
                                    feedRepository.feedsPromises.first?.resolve(.success([]))
                                }

                                it("asks the feed repository to import the feed") {
                                    expect(feedRepository.didCreateFeed) == true
                                }

                                context("when the feed repository creates the feed") {
                                    var feed: Feed!
                                    beforeEach {
                                        feedRepository.didUpdateFeed = nil
                                        feed = Feed(title: "", url: url, summary: "", tags: [], articles: [], image: nil)
                                        feedRepository.newFeedCallback(feed)
                                    }

                                    it("sets that feed's url") {
                                        expect(feed.url) == url
                                    }

                                    it("waits for the feed to actaully be saved to the database (and potentially pasiphae)") {
                                        expect(feedRepository.didUpdateFeed).to(beNil())
                                    }

                                    context("when the feed is saved to the database") {
                                        beforeEach {
                                            feedRepository.newFeedPromises.last?.resolve(.success())
                                        }

                                        it("it tells the feed repository to update the feed from the network") {
                                            expect(feedRepository.didUpdateFeed) == feed
                                        }

                                        it("calls the callback when the feed repository finishes updating the feed") {
                                            feedRepository.updateSingleFeedCallback(feed, nil)

                                            expect(didImport) == true
                                        }

                                        it("calls the callback when the feed repository errors updating the feed") {
                                            feedRepository.updateSingleFeedCallback(feed, NSError(domain: "", code: 0, userInfo: nil))
                                            
                                            expect(didImport) == true
                                        }
                                    }
                                }
                            }
                        }

                        describe("when the feed repository fails") {
                            beforeEach {
                                feedRepository.feedsPromises.first?.resolve(.failure(.unknown))
                            }
                            // TODO: implement the sad path
                        }
                    }
                }

                context("when the network returns an OPML file") {
                    let opmlURL = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "opml")!
                    let opmlData = try? Data(contentsOf: opmlURL)

                    beforeEach {
                        urlSession.lastCompletionHandler(opmlData, nil, nil)
                    }

                    it("calls the callback with .OPML and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.opml(url, 4)
                    }

                    context("later calling -importItem:callback: with that url") {
                        var didImport = false
                        beforeEach {
                            urlSession.lastURL = nil
                            _ = subject.importItem(url).then { _ in
                                didImport = true
                            }
                        }

                        it("does not make another urlSession call") {
                            expect(urlSession.lastURL).to(beNil())
                        }

                        it("asks the opml service to import the feed list") {
                            expect(opmlService.importOPMLURL) == url
                        }

                        it("calls the callback when the opml service finishes") {
                            opmlService.importOPMLCompletion([])

                            expect(didImport) == true
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
                        urlSession.lastCompletionHandler(webPageData, nil, nil)
                    }

                    it("calls the callback with the url and the list of found feed urls") {
                        expect(receivedItem) == ImportUseCaseItem.webPage(url, [feed1Url, feed2Url])
                    }

                    context("later calling -importItem:callback: with one of the found feed urls") {
                        var didImport = false
                        beforeEach {
                            urlSession.lastURL = nil
                            _ = subject.importItem(feed1Url).then { _ in
                                didImport = true
                            }
                        }

                        it("does not make another urlSession call") {
                            expect(urlSession.lastURL).to(beNil())
                        }

                        it("asks the feed repository for a list of all feeds") {
                            expect(feedRepository.feedsPromises.count) > 0
                        }

                        describe("when the feed repository succeeds") {
                            context("and a feed with the proposed feed url is in the feeds list") {
                                beforeEach {
                                    let existingFeed = Feed(title: "", url: feed1Url, summary: "", tags: [], articles: [], image: nil)

                                    feedRepository.feedsPromises.first?.resolve(.success([existingFeed]))
                                }

                                it("does not ask the feed repository to import the feed") {
                                    expect(feedRepository.didCreateFeed) == false
                                }

                                it("calls the callback") {
                                    expect(didImport) == true
                                }
                            }

                            context("and a feed with the proposed feed url is not in the feeds list") {
                                beforeEach {
                                    feedRepository.feedsPromises.first?.resolve(.success([]))
                                }

                                it("asks the feed repository to import the feed") {
                                    expect(feedRepository.didCreateFeed) == true
                                }

                                context("when the feed repository creates the feed") {
                                    var feed: Feed!
                                    beforeEach {
                                        feed = Feed(title: "", url: feed1Url, summary: "", tags: [], articles: [], image: nil)
                                        feedRepository.newFeedCallback(feed)
                                        feedRepository.newFeedPromises.last?.resolve(.success())
                                    }

                                    it("sets that feed's url") {
                                        expect(feed.url) == feed1Url
                                    }

                                    it("it tells the feed repository to update the feed from the network") {
                                        expect(feedRepository.didUpdateFeed) == feed
                                    }

                                    it("calls the callback when the feed repository finishes updating the feed") {
                                        feedRepository.updateSingleFeedCallback(feed, nil)

                                        expect(didImport) == true
                                    }

                                    it("calls the callback when the feed repository errors updating the feed") {
                                        feedRepository.updateSingleFeedCallback(feed, NSError(domain: "", code: 0, userInfo: nil))

                                        expect(didImport) == true
                                    }
                                }
                            }
                        }

                        describe("when the feed repository fails") {
                            beforeEach {
                                feedRepository.feedsPromises.first?.resolve(.failure(.unknown))
                            }
                            // TODO: implement the sad path
                        }
                    }
                }

                context("when the network returns an error") {
                    beforeEach {
                        let error = NSError(domain: "hello", code: 0, userInfo: nil)
                        urlSession.lastCompletionHandler(nil, nil, error)
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

                    it("does not call the urlSession") {
                        expect(urlSession.lastURL).to(beNil())
                    }

                    it("calls the callback with .Feed and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.feed(feedURL, 100)
                    }

                    context("later calling -importItem:callback: with that url") {
                        var didImport = false
                        beforeEach {
                            _ = subject.importItem(feedURL).then { _ in
                                didImport = true
                            }
                        }

                        it("asks the feed repository for the most recent list of feeds") {
                            expect(feedRepository.feedsPromises.count) > 0
                        }

                        describe("when the feeds repository succeeds") {
                            context("and a feed with the proposed feed url is in the feeds list") {
                                beforeEach {
                                    let existingFeed = Feed(title: "", url: URL(string: "http://younata.github.io/")!, summary: "", tags: [], articles: [], image: nil)

                                    feedRepository.feedsPromises.first?.resolve(.success([existingFeed]))
                                }

                                it("does not ask the feed repository to import the feed") {
                                    expect(feedRepository.didCreateFeed) == false
                                }

                                it("calls the callback") {
                                    expect(didImport) == true
                                }
                            }

                            context("and a feed with the proposed feed url is not in the feeds list") {
                                beforeEach {
                                    feedRepository.feedsPromises.first?.resolve(.success([]))
                                }

                                it("asks the feed repository to import the feed") {
                                    expect(feedRepository.didCreateFeed) == true
                                }

                                context("when the feed repository creates the feed") {
                                    var feed: Feed!
                                    beforeEach {
                                        feed = Feed(title: "", url: URL(string: "http://iotlist.co/posts.atom")!, summary: "", tags: [], articles: [], image: nil)
                                        feedRepository.newFeedCallback(feed)
                                        feedRepository.newFeedPromises.last?.resolve(.success())
                                    }

                                    it("sets that feed's url") {
                                        expect(feed.url) == URL(string: "http://iotlist.co/posts.atom")
                                    }

                                    it("it tells the feed repository to update the feed from the network") {
                                        expect(feedRepository.didUpdateFeed) == feed
                                    }

                                    it("calls the callback when the feed repository finishes updating the feed") {
                                        feedRepository.updateSingleFeedCallback(feed, nil)

                                        expect(didImport) == true
                                    }

                                    it("calls the callback when the feed repository errors updating the feed") {
                                        feedRepository.updateSingleFeedCallback(feed, NSError(domain: "", code: 0, userInfo: nil))

                                        expect(didImport) == true
                                    }
                                }
                            }
                        }

                        describe("when the feed repository fails") {
                            beforeEach {
                                feedRepository.feedsPromises.first?.resolve(.failure(.unknown))
                            }
                            // TODO: implement the sad path
                        }
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
                        expect(urlSession.lastURL).to(beNil())
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
                        expect(urlSession.lastURL).to(beNil())
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

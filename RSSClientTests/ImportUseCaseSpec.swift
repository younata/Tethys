import Quick
import Nimble

import rNews
import rNewsKit

class ImportUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: DefaultImportUseCase!
        var urlSession: FakeURLSession!
        var feedRepository: FakeFeedRepository!
        var opmlService: FakeOPMLService!

        beforeEach {
            urlSession = FakeURLSession()
            feedRepository = FakeFeedRepository()
            opmlService = FakeOPMLService()
            subject = DefaultImportUseCase(
                urlSession: urlSession,
                feedRepository: feedRepository,
                opmlService: opmlService
            )
        }

        describe("-scanForImportable:progress:callback:") {
            context("when asked to scan a network URL") {
                let url = NSURL(string: "https://example.com/item")!

                var receivedItem: ImportUseCaseItem?

                beforeEach {
                    receivedItem = nil
                    subject.scanForImportable(url) {
                        receivedItem = $0
                    }
                }

                it("makes a call to the network for the item") {
                    expect(urlSession.lastURL) == url
                }

                context("when the network returns a feed file") {
                    let feedURL = NSBundle(forClass: self.classForCoder).URLForResource("feed", withExtension: "rss")!
                    let feedData = NSData(contentsOfURL: feedURL)

                    beforeEach {
                        urlSession.lastCompletionHandler(feedData, nil, nil)
                    }

                    it("calls the callback with .Feed and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.Feed(url)
                    }

                    context("later calling -importItem:callback: with that url") {
                        var didImport = false
                        beforeEach {
                            urlSession.lastURL = nil
                            subject.importItem(url) {
                                didImport = true
                            }
                        }

                        it("does not make another urlSession call") {
                            expect(urlSession.lastURL).to(beNil())
                        }

                        it("asks the feed repository to import the feed") {
                            expect(feedRepository.didCreateFeed) == true
                        }

                        context("when the feed repository creates the feed") {
                            var feed: Feed!
                            beforeEach {
                                feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                                feedRepository.newFeedCallback(feed)
                            }

                            it("sets that feed's url") {
                                expect(feed.url) == url
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

                context("when the network returns an OPML file") {
                    let opmlURL = NSBundle(forClass: self.classForCoder).URLForResource("test", withExtension: "opml")!
                    let opmlData = NSData(contentsOfURL: opmlURL)

                    beforeEach {
                        urlSession.lastCompletionHandler(opmlData, nil, nil)
                    }

                    it("calls the callback with .OPML and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.OPML(url)
                    }

                    context("later calling -importItem:callback: with that url") {
                        var didImport = false
                        beforeEach {
                            urlSession.lastURL = nil
                            subject.importItem(url) {
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
                    let feed1Url = NSURL(string: "/feed.xml", relativeToURL: url)!.absoluteURL
                    let feed2html = "<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS\" href=\"/feed2.xml\">"
                    let feed2Url = NSURL(string: "/feed2.xml", relativeToURL: url)!.absoluteURL

                    let webPageString = "<html><head>\(feed1html)\(feed2html)</head><body></body></html>"
                    let webPageData = webPageString.dataUsingEncoding(NSUTF8StringEncoding)!

                    beforeEach {
                        urlSession.lastCompletionHandler(webPageData, nil, nil)
                    }

                    it("calls the callback with the url and the list of found feed urls") {
                        expect(receivedItem) == ImportUseCaseItem.WebPage(url, [feed1Url, feed2Url])
                    }

                    context("later calling -importItem:callback: with one of the found feed urls") {
                        var didImport = false
                        beforeEach {
                            urlSession.lastURL = nil
                            subject.importItem(feed1Url) {
                                didImport = true
                            }
                        }

                        it("does not make another urlSession call") {
                            expect(urlSession.lastURL).to(beNil())
                        }

                        it("asks the feed repository to import the feed") {
                            expect(feedRepository.didCreateFeed) == true
                        }

                        context("when the feed repository creates the feed") {
                            var feed: Feed!
                            beforeEach {
                                feed = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                                feedRepository.newFeedCallback(feed)
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

                context("when the network returns an error") {
                    beforeEach {
                        let error = NSError(domain: "hello", code: 0, userInfo: nil)
                        urlSession.lastCompletionHandler(nil, nil, error)
                    }

                    it("calls the callback with .None and the URL") {
                        expect(receivedItem) == ImportUseCaseItem.None(url)
                    }
                }
            }

            context("when asked to scan a file system URL") {
                pending("Write me!") {}
            }
        }

        describe("-importItem:callback:") {
            let url = NSURL(string: "https://example.com/item")!

            it("informs the user that we don't have data for this url") {
                var didImport = false
                subject.importItem(url) {
                    didImport = true
                }
                expect(didImport) == true
            }
        }
    }
}

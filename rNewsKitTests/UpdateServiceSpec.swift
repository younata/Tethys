import Quick
import Nimble
@testable import rNewsKit

class UpdateServiceSpec: QuickSpec {
    override func spec() {
        var subject: UpdateService! = nil
        var urlSession: FakeURLSession! = nil
        var urlSessionDelegate: URLSessionDelegate! = nil
        var dataService: InMemoryDataService! = nil

        beforeEach {
            urlSessionDelegate = URLSessionDelegate()
            dataService = InMemoryDataService()
            urlSession = FakeURLSession()
            urlSessionDelegate = URLSessionDelegate()

            subject = UpdateService(dataService: dataService, urlSession: urlSession)

            // we make the assumption that the urlSession's delegate is an instance of URLSessionDelegate.

            urlSessionDelegate.delegate = subject
        }

        describe("updating a feed") {
            context("trying to update a query feed") {
                let query = Feed(title: "query", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                var updatedFeed: Feed? = nil

                beforeEach {
                    dataService.feeds = [query]
                    subject.updateFeed(query) { updatedFeed = $0 }
                }

                it("should not make a network request") {
                    expect(urlSession.lastURL).to(beNil())
                }

                it("should call the callback with the original feed") {
                    expect(updatedFeed) == query
                }
            }

            describe("updating a standard feed") {
                var feed: Feed! = nil
                var updatedFeed: Feed? = nil

                beforeEach {
                    feed = Feed(title: "feed", url: NSURL(string: "https://example.com/feed"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    dataService.feeds = [feed]

                    updatedFeed = nil
                    subject.updateFeed(feed) { updatedFeed = $0 }
                }

                it("should make a call to download the feed URL") {
                    expect(urlSession.lastURL) == feed.url
                    expect(urlSession.lastDownloadTask?.originalRequest?.URL) == feed.url
                }

                context("when the download completes") {
                    context("and the downloaded feed data has no image url") {
                        beforeEach {
                            guard urlSession.lastDownloadTask != nil else { fail(); return }
                            let location = NSBundle(forClass: self.classForCoder).URLForResource("feed", withExtension: "rss")!
                            urlSessionDelegate.URLSession(urlSession, downloadTask: urlSession.lastDownloadTask!, didFinishDownloadingToURL: location)
                        }

                        it("should call the callback with the updated feed") {
                            expect(updatedFeed).toNot(beNil())
                            guard let feed = updatedFeed else { return }
                            expect(feed.title) == "Iotlist"
                            expect(feed.summary) == "The list for the Internet of Things"
                            expect(feed.articlesArray).toNot(beEmpty())
                        }
                    }

                    context("and the downloaded feed data has an image url and the feed has no image downloaded yet") {
                        beforeEach {
                            guard urlSession.lastDownloadTask != nil else { fail(); return }
                            let location = NSBundle(forClass: self.classForCoder).URLForResource("feed2", withExtension: "rss")!
                            urlSessionDelegate.URLSession(urlSession, downloadTask: urlSession.lastDownloadTask!, didFinishDownloadingToURL: location)
                        }

                        it("should not call the callback yet") {
                            expect(updatedFeed).to(beNil())
                        }

                        it("should try to download the image") {
                            expect(urlSession.lastURL) == NSURL(string: "http://example.org/icon.png")
                        }

                        context("when the image download completes") {

                            beforeEach {
                                guard let task = urlSession.lastDownloadTask else { fail(); return }
                                task._response = NSURLResponse(URL: NSURL(string: "http://example.org/icon.png")!, MIMEType: "image/jpg", expectedContentLength: 0, textEncodingName: nil)
                                let location = NSBundle(forClass: self.classForCoder).URLForResource("test", withExtension: "jpg")!
                                urlSessionDelegate.URLSession(urlSession, downloadTask: task, didFinishDownloadingToURL: location)
                            }

                            it("should call the callback with the updated feed and image") {
                                expect(updatedFeed?.title) == "objc.io"
                                expect(updatedFeed?.summary) == "A periodical about best practices and advanced techniques for iOS and OS X development."
                                expect(updatedFeed?.image).toNot(beNil())
                                expect(updatedFeed?.articlesArray).toNot(beEmpty())
                            }
                        }
                    }

                    describe("and the downloaded feed data has image url but the feed has an image downloaded already") {
                        beforeEach {
                            guard urlSession.lastDownloadTask != nil else { fail(); return }
                            let bundle = NSBundle(forClass: self.classForCoder)

                            let image = bundle.URLForResource("test", withExtension: "jpg")!
                            feed.image = Image(data: NSData(contentsOfURL: image)!)
                            expect(feed.image).toNot(beNil())

                            let location = bundle.URLForResource("feed2", withExtension: "rss")!
                            urlSessionDelegate.URLSession(urlSession, downloadTask: urlSession.lastDownloadTask!, didFinishDownloadingToURL: location)
                        }

                        it("should call the callback yet") {
                            expect(updatedFeed).toNot(beNil())
                            guard updatedFeed != nil else { return }
                            expect(updatedFeed?.title) == "objc.io"
                            expect(updatedFeed?.summary) == "A periodical about best practices and advanced techniques for iOS and OS X development."
                            expect(updatedFeed?.image).toNot(beNil())
                            expect(updatedFeed?.articlesArray).toNot(beEmpty())
                        }

                        it("should not try to download the image") {
                            expect(urlSession.lastURL) == feed.url
                        }
                    }
                }
            }
        }
    }
}

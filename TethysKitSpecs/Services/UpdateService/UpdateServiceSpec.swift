import Quick
import Nimble
import CBGPromise
import Result
@testable import TethysKit

class UpdateServiceSpec: QuickSpec {
    override func spec() {
        var subject: OldUpdateService!
        var urlSession: FakeURLSession!
        var urlSessionDelegate: TethysKitURLSessionDelegate!
        var dataServiceFactory: FakeDataServiceFactory!
        var dataService: InMemoryDataService!
        var workerQueue: FakeOperationQueue!

        beforeEach {
            let mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            dataServiceFactory = FakeDataServiceFactory()
            dataService = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())
            dataServiceFactory.currentDataService = dataService
            urlSession = FakeURLSession()
            urlSessionDelegate = TethysKitURLSessionDelegate()

            workerQueue = FakeOperationQueue()
            workerQueue.runSynchronously = true

            subject = OldUpdateService(
                dataServiceFactory: dataServiceFactory,
                urlSession: urlSession,
                urlSessionDelegate: urlSessionDelegate,
                workerQueue: workerQueue
            )
        }

        describe("updating a feed") {
            var feed: TethysKit.Feed! = nil
            var updatedFeed: TethysKit.Feed?
            var receivedError: TethysError?

            var updateFeedFuture: Future<Result<TethysKit.Feed, TethysError>>!

            beforeEach {
                feed = TethysKit.Feed(title: "feed", url: URL(string: "http://www.objc.io")!, summary: "", tags: [], articles: [], image: nil)
                dataService.feeds = [feed]

                updatedFeed = nil
                receivedError = nil
                updateFeedFuture = subject.updateFeed(feed).then {
                    if case let .success(feed) = $0 {
                        updatedFeed = feed
                    } else if case let .failure(error) = $0 {
                        receivedError = error
                    }
                }
            }

            it("should make a call to download the feed URL") {
                expect(urlSession.lastURL) == feed.url
                expect(urlSession.lastDownloadTask?.originalRequest?.url) == feed.url
            }

            context("when the download completes") {
                context("and the downloaded feed data has no image url") {
                    beforeEach {
                        guard urlSession.lastDownloadTask != nil else { fail(); return }
                        let location = Bundle(for: self.classForCoder).url(forResource: "feed", withExtension: "rss")!
                        urlSessionDelegate.urlSession(urlSession, downloadTask: urlSession.lastDownloadTask!, didFinishDownloadingTo: location)

                        _ = updateFeedFuture.wait()
                    }

                    it("resolves the promise with the updated feed") {
                        expect(updatedFeed).toNot(beNil())
                        guard let feed = updatedFeed else { return }
                        expect(feed.title) == "Rachel Brindle"
                        expect(feed.summary) == "Software Engineer and Electric Vehicle enthusiast"
                        expect(feed.articlesArray).toNot(beEmpty())
                    }
                }

                context("and the downloaded feed data has an image url and the feed has no image downloaded yet") {
                    beforeEach {
                        guard urlSession.lastDownloadTask != nil else { fail(); return }
                        let location = Bundle(for: self.classForCoder).url(forResource: "feed2", withExtension: "rss")!
                        urlSessionDelegate.urlSession(urlSession, downloadTask: urlSession.lastDownloadTask!, didFinishDownloadingTo: location)
                    }

                    it("does not resolve the future yet") {
                        expect(updateFeedFuture.value).to(beNil())
                    }

                    it("tries to download the image") {
                        expect(urlSession.lastURL) == URL(string: "http://example.org/icon.png")
                    }

                    context("when the image download completes") {
                        beforeEach {
                            guard let task = urlSession.lastDownloadTask else { fail(); return }
                            task._response = URLResponse(url: URL(string: "http://example.org/icon.png")!, mimeType: "image/jpg", expectedContentLength: 0, textEncodingName: nil)
                            let location = Bundle(for: self.classForCoder).url(forResource: "test", withExtension: "jpg")!
                            urlSessionDelegate.urlSession(urlSession, downloadTask: task, didFinishDownloadingTo: location)

                            _ = updateFeedFuture.wait()
                        }

                        it("should resolve the promise with the updated feed") {
                            expect(updatedFeed?.title) == "objc.io"
                            expect(updatedFeed?.summary) == "A periodical about best practices and advanced techniques for iOS and OS X development."
                            expect(updatedFeed?.image).toNot(beNil())
                            expect(updatedFeed?.articlesArray).toNot(beEmpty())
                        }

                        it("does not have an error in the resolved value") {
                            expect(receivedError).to(beNil())
                        }
                    }

                    context("if the image download errors out") {
                        let error = NSError(domain: "com.example.error", code: 20, userInfo: nil)
                        beforeEach {
                            guard let task = urlSession.lastDownloadTask else { fail(); return }
                            task._response = URLResponse(url: URL(string: "http://example.org/icon.png")!, mimeType: "image/jpg", expectedContentLength: 0, textEncodingName: nil)
                            urlSessionDelegate.urlSession(urlSession, task: task, didCompleteWithError: error)

                            _ = updateFeedFuture.wait()
                        }

                        it("should resolve the promise with the updated feed") {
                            expect(updatedFeed?.title) == "objc.io"
                            expect(updatedFeed?.summary) == "A periodical about best practices and advanced techniques for iOS and OS X development."
                            expect(updatedFeed?.image).to(beNil())
                            expect(updatedFeed?.articlesArray).toNot(beEmpty())
                        }

                        it("should not have an error in the callback") {
                            expect(receivedError).to(beNil())
                        }
                    }
                }

                describe("and the downloaded feed data has image url but the feed has an image downloaded already") {
                    beforeEach {
                        guard urlSession.lastDownloadTask != nil else { fail(); return }
                        let bundle = Bundle(for: self.classForCoder)

                        let image = bundle.url(forResource: "test", withExtension: "jpg")!
                        feed.image = Image(data: try! Data(contentsOf: image))
                        expect(feed.image).toNot(beNil())

                        let location = bundle.url(forResource: "feed2", withExtension: "rss")!
                        urlSessionDelegate.urlSession(urlSession, downloadTask: urlSession.lastDownloadTask!, didFinishDownloadingTo: location)

                        _ = updateFeedFuture.wait()
                    }

                    it("resolves the promise") {
                        expect(updatedFeed).toNot(beNil())
                        guard updatedFeed != nil else { return }
                        expect(updatedFeed?.title) == "objc.io"
                        expect(updatedFeed?.summary) == "A periodical about best practices and advanced techniques for iOS and OS X development."
                        expect(updatedFeed?.image).toNot(beNil())
                        expect(updatedFeed?.articlesArray).toNot(beEmpty())
                    }

                    it("does not try to download the image") {
                        expect(urlSession.lastURL) == feed.url
                    }
                }
            }

            context("if the download errors out") {
                let error = NSError(domain: "com.example.error", code: 22, userInfo: nil)
                beforeEach {
                    guard let task = urlSession.lastDownloadTask else { fail(); return }
                    urlSessionDelegate.urlSession(urlSession, task: task, didCompleteWithError: error)

                    _ = updateFeedFuture.wait()
                }

                it("resolves the promise with the original feed") {
                    expect(updatedFeed).to(beNil())
                }

                it("should have an error in the callback") {
                    expect(receivedError) == TethysError.network(URL(string: "http://www.objc.io")!, .unknown)
                }
            }
        }
    }
}

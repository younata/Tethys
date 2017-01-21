import Quick
import Nimble
import CBGPromise
import Result
import Sinope
import Freddy
@testable import TethysKit

class UpdateServiceSpec: QuickSpec {
    override func spec() {
        var subject: UpdateService!
        var urlSession: FakeURLSession!
        var urlSessionDelegate: TethysKitURLSessionDelegate!
        var dataServiceFactory: FakeDataServiceFactory!
        var dataService: InMemoryDataService!
        var workerQueue: FakeOperationQueue!
        var sinopeRepository: FakeSinopeRepository!

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

            sinopeRepository = FakeSinopeRepository()

            subject = UpdateService(
                dataServiceFactory: dataServiceFactory,
                urlSession: urlSession,
                urlSessionDelegate: urlSessionDelegate,
                workerQueue: workerQueue,
                sinopeRepository: sinopeRepository
            )
        }

        describe("updating multiple feeds") {
            var updateFeedsFuture: Future<Result<[TethysKit.Feed], TethysError>>!
            var fetchPromise: Promise<Result<[Sinope.Feed], SinopeError>>!
            let date = Date()
            let feedToUpdate = TethysKit.Feed(title: "feed", url: URL(string: "https://example.com/feed")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil, lastUpdated: date)

            var progressCallbackCallCount = 0
            var progressCallbackArgs: [(Int, Int)] = []

            beforeEach {
                dataService.feeds = [feedToUpdate]

                progressCallbackCallCount = 0
                progressCallbackArgs = []

                fetchPromise = Promise<Result<[Sinope.Feed], SinopeError>>()
                sinopeRepository.fetchReturns(fetchPromise.future)
                updateFeedsFuture = subject.updateFeeds { currentProgress, estimatedProgress in
                    progressCallbackArgs.append((currentProgress, estimatedProgress))
                    progressCallbackCallCount += 1
                }
            }

            it("returns an in-progress promise") {
                expect(updateFeedsFuture.value).to(beNil())
            }

            it("makes a request to the sinopeRepository") {
                expect(sinopeRepository.fetchCallCount) == 1
                guard sinopeRepository.fetchCallCount == 1 else { return }
                let args = sinopeRepository.fetchArgsForCall(0)
                expect(args) == [feedToUpdate.url: feedToUpdate.lastUpdated]
            }

            describe("when the request succeeds") {
                var feed: TethysKit.Feed! = nil

                beforeEach {
                    feed = TethysKit.Feed(title: "feed", url: URL(string: "https://example.com/feed")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    dataService.feeds = [feed]
                    // hm.

                    let data: Data = ("{\"title\": \"feed title\"," +
                        "\"url\": \"https://example.com/feed\"," +
                        "\"summary\": \"test\"," +
                        "\"image_url\": \"https://example.com/image.png\"," +
                        "\"last_updated\": \"2015-12-23T00:00:00.000Z\"," +
                        "\"articles\": [" +
                        "{\"title\": \"Example 1\", \"url\": \"https://example.com/1/\", \"summary\": \"test\", \"published\": \"2015-12-23T00:00:00.000Z\", \"updated\": null, \"content\": null, \"authors\": []}" +
                        "]}").data(using: String.Encoding.utf8)!

                    let json = try! JSON(data: data)
                    let sinopeFeed = try! Feed(json: json)

                    fetchPromise.resolve(.success([sinopeFeed]))
                }

                it("calls the callback as the feeds are processed") {
                    expect(progressCallbackCallCount) == 2
                    expect(progressCallbackArgs[0].0) == 1
                    expect(progressCallbackArgs[0].1) == 2
                    expect(progressCallbackArgs[1].0) == 2
                    expect(progressCallbackArgs[1].1) == 2
                }

                it("resolves the promise with all updated feeds") {
                    expect(updateFeedsFuture.value).toNot(beNil())
                    guard let feed = updateFeedsFuture.value?.value?.first else { return }
                    expect(feed.title) == "feed title"
                    expect(feed.summary) == "test"
                    expect(feed.articlesArray.count) == 1
                }
            }


            describe("and the request succeeds with feeds that don't exist locally yet") {
                beforeEach {
                    dataService.feeds = []

                    let data: Data = ("{\"title\": \"feed title\"," +
                        "\"url\": \"https://example.com/feed\"," +
                        "\"summary\": \"test\"," +
                        "\"image_url\": \"https://example.com/image.png\"," +
                        "\"last_updated\": \"2015-12-23T00:00:00.000Z\"," +
                        "\"articles\": [" +
                        "{\"title\": \"Example 1\", \"url\": \"https://example.com/1/\", \"summary\": \"test\", \"published\": \"2015-12-23T00:00:00.000Z\", \"updated\": null, \"content\": null, \"authors\": []}" +
                        "]}").data(using: String.Encoding.utf8)!

                    let json = try! JSON(data: data)
                    let sinopeFeed = try! Feed(json: json)

                    fetchPromise.resolve(.success([sinopeFeed]))
                }

                it("creates a new feed with that data") {
                    expect(dataService.feeds.count) == 1
                    guard let feed = dataService.feeds.first else { return }
                    expect(feed.title) == "feed title"
                    expect(feed.summary) == "test"
                    expect(feed.url) == URL(string: "https://example.com/feed")
                    expect(feed.articlesArray.count) == 1
                }

                it("calls the callback as the feeds are processed") {
                    expect(progressCallbackCallCount) == 2
                    expect(progressCallbackArgs[0].0) == 1
                    expect(progressCallbackArgs[0].1) == 2
                    expect(progressCallbackArgs[1].0) == 2
                    expect(progressCallbackArgs[1].1) == 2
                }

                it("should resolve the promise with all updated feeds") {
                    expect(updateFeedsFuture.value).toNot(beNil())
                    guard let feed = updateFeedsFuture.value?.value?.first else { return }
                    expect(feed.title) == "feed title"
                    expect(feed.summary) == "test"
                    expect(feed.articlesArray.count) == 1
                }
            }

            describe("when the request fails") {
                beforeEach {
                    fetchPromise.resolve(.failure(.unknown))
                }

                it("wraps the error") {
                    expect(updateFeedsFuture.value).toNot(beNil())
                    expect(updateFeedsFuture.value?.error) == TethysError.backend(.unknown)
                }
            }
        }

        describe("updating a feed") {
            describe("updating a standard feed") {
                var feed: TethysKit.Feed! = nil
                var updatedFeed: TethysKit.Feed?
                var receivedError: TethysError?

                var updateFeedFuture: Future<Result<TethysKit.Feed, TethysError>>!

                beforeEach {
                    feed = TethysKit.Feed(title: "feed", url: URL(string: "http://www.objc.io")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
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
                            expect(feed.title) == "Iotlist"
                            expect(feed.summary) == "The list for the Internet of Things"
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
}

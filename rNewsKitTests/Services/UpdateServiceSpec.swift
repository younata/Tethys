import Quick
import Nimble
import CBGPromise
import Result
import Sinope
import Freddy
@testable import rNewsKit

class UpdateServiceSpec: QuickSpec {
    override func spec() {
        var subject: UpdateService!
        var urlSession: FakeURLSession!
        var urlSessionDelegate: URLSessionDelegate!
        var dataServiceFactory: FakeDataServiceFactory!
        var dataService: InMemoryDataService!
        var workerQueue: FakeOperationQueue!
        var sinopeRepository: FakeSinopeRepository!

        beforeEach {
            urlSessionDelegate = URLSessionDelegate()
            let mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            dataServiceFactory = FakeDataServiceFactory()
            dataService = InMemoryDataService(mainQueue: mainQueue, searchIndex: FakeSearchIndex())
            dataServiceFactory.currentDataService = dataService
            urlSession = FakeURLSession()
            urlSessionDelegate = URLSessionDelegate()

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
            var updateFeedsFuture: Future<Result<(NSDate, [rNewsKit.Feed]), RNewsError>>!
            var fetchPromise: Promise<Result<(NSDate, [Sinope.Feed]), SinopeError>>!
            let date = NSDate()

            var progressCallbackCallCount = 0
            var progressCallbackArgs: [(Int, Int)] = []

            beforeEach {
                progressCallbackCallCount = 0
                progressCallbackArgs = []

                fetchPromise = Promise<Result<(NSDate, [Sinope.Feed]), SinopeError>>()
                sinopeRepository.fetchReturns(fetchPromise.future)
                updateFeedsFuture = subject.updateFeeds(date) { currentProgress, estimatedProgress in
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
                expect(args) == date
            }

            describe("when the request succeeds") {
                var feed: rNewsKit.Feed! = nil
                let updatedDate = NSDate()

                beforeEach {
                    feed = rNewsKit.Feed(title: "feed", url: NSURL(string: "https://example.com/feed"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    dataService.feeds = [feed]
                    // hm.

                    let data: NSData = ("{\"title\": \"feed title\"," +
                        "\"url\": \"https://example.com/feed\"," +
                        "\"summary\": \"test\"," +
                        "\"image_url\": \"https://example.com/image.png\"," +
                        "\"articles\": [" +
                        "{\"title\": \"Example 1\", \"url\": \"https://example.com/1/\", \"summary\": \"test\", \"published\": \"2015-12-23T00:00:00.000Z\", \"updated\": null, \"content\": null, \"authors\": []}" +
                        "]}").dataUsingEncoding(NSUTF8StringEncoding)!

                    let json = try! JSON(data: data)
                    let sinopeFeed = try! Feed(json: json)

                    fetchPromise.resolve(.Success(updatedDate, [sinopeFeed]))
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
                    guard let receivedDate = updateFeedsFuture.value?.value?.0 else { return }
                    guard let feed = updateFeedsFuture.value?.value?.1.first else { return }
                    expect(receivedDate) == updatedDate
                    expect(feed.title) == "feed title"
                    expect(feed.summary) == "test"
                    expect(feed.articlesArray.count) == 1
                }
            }


            describe("and the request succeeds with feeds that don't exist locally yet") {
                let updatedDate = NSDate()

                beforeEach {
                    dataService.feeds = []

                    let data: NSData = ("{\"title\": \"feed title\"," +
                        "\"url\": \"https://example.com/feed\"," +
                        "\"summary\": \"test\"," +
                        "\"image_url\": \"https://example.com/image.png\"," +
                        "\"articles\": [" +
                        "{\"title\": \"Example 1\", \"url\": \"https://example.com/1/\", \"summary\": \"test\", \"published\": \"2015-12-23T00:00:00.000Z\", \"updated\": null, \"content\": null, \"authors\": []}" +
                        "]}").dataUsingEncoding(NSUTF8StringEncoding)!

                    let json = try! JSON(data: data)
                    let sinopeFeed = try! Feed(json: json)

                    fetchPromise.resolve(.Success(updatedDate, [sinopeFeed]))
                }

                it("creates a new feed with that data") {
                    expect(dataService.feeds.count) == 1
                    guard let feed = dataService.feeds.first else { return }
                    expect(feed.title) == "feed title"
                    expect(feed.summary) == "test"
                    expect(feed.url) == NSURL(string: "https://example.com/feed")
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
                    guard let receivedDate = updateFeedsFuture.value?.value?.0 else { return }
                    guard let feed = updateFeedsFuture.value?.value?.1.first else { return }
                    expect(receivedDate) == updatedDate
                    expect(feed.title) == "feed title"
                    expect(feed.summary) == "test"
                    expect(feed.articlesArray.count) == 1
                }
            }

            describe("when the request fails") {
                beforeEach {
                    fetchPromise.resolve(.Failure(.Unknown))
                }

                it("wraps the error") {
                    expect(updateFeedsFuture.value).toNot(beNil())
                    expect(updateFeedsFuture.value?.error) == RNewsError.Backend(.Unknown)
                }
            }
        }

        describe("updating a feed") {
            context("trying to update a query feed") {
                let query = rNewsKit.Feed(title: "query", url: nil, summary: "", query: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                var updatedFeed: rNewsKit.Feed? = nil
                var receivedError: NSError? = nil

                beforeEach {
                    dataService.feeds = [query]
                    receivedError = nil
                    subject.updateFeed(query) {
                        updatedFeed = $0
                        receivedError = $1
                    }
                }

                it("should not make a network request") {
                    expect(urlSession.lastURL).to(beNil())
                }

                it("should call the callback with the original feed") {
                    expect(updatedFeed) == query
                }

                it("should not have any error in the callback") {
                    expect(receivedError).to(beNil())
                }
            }

            describe("updating a standard feed") {
                var feed: rNewsKit.Feed! = nil
                var updatedFeed: rNewsKit.Feed? = nil
                var receivedError: NSError? = nil

                beforeEach {
                    feed = rNewsKit.Feed(title: "feed", url: NSURL(string: "https://example.com/feed"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    dataService.feeds = [feed]

                    updatedFeed = nil
                    receivedError = nil
                    subject.updateFeed(feed) {
                        updatedFeed = $0
                        receivedError = $1
                    }
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

                        it("should not have an error in the callback") {
                            expect(receivedError).to(beNil())
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

                            it("should call the callback with the updated feed") {
                                expect(updatedFeed?.title) == "objc.io"
                                expect(updatedFeed?.summary) == "A periodical about best practices and advanced techniques for iOS and OS X development."
                                expect(updatedFeed?.image).toNot(beNil())
                                expect(updatedFeed?.articlesArray).toNot(beEmpty())
                            }

                            it("should not have an error in the callback") {
                                expect(receivedError).to(beNil())
                            }
                        }

                        context("if the image download errors out") {
                            let error = NSError(domain: "com.example.error", code: 20, userInfo: nil)
                            beforeEach {
                                guard let task = urlSession.lastDownloadTask else { fail(); return }
                                task._response = NSURLResponse(URL: NSURL(string: "http://example.org/icon.png")!, MIMEType: "image/jpg", expectedContentLength: 0, textEncodingName: nil)
                                urlSessionDelegate.URLSession(urlSession, task: task, didCompleteWithError: error)
                            }

                            it("should call the callback with an error and an updated feed") {
                                expect(updatedFeed?.title) == "objc.io"
                                expect(updatedFeed?.summary) == "A periodical about best practices and advanced techniques for iOS and OS X development."
                                expect(updatedFeed?.image).to(beNil())
                                expect(updatedFeed?.articlesArray).toNot(beEmpty())
                            }

                            it("should have an error in the callback") {
                                expect(receivedError) == error
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

                context("if the download errors out") {
                    let error = NSError(domain: "com.example.error", code: 22, userInfo: nil)
                    beforeEach {
                        guard let task = urlSession.lastDownloadTask else { fail(); return }
                        urlSessionDelegate.URLSession(urlSession, task: task, didCompleteWithError: error)
                    }

                    it("should call the callback with the original feed") {
                        expect(updatedFeed) === feed
                    }

                    it("should have an error in the callback") {
                        expect(receivedError) == error
                    }
                }
            }
        }
    }
}

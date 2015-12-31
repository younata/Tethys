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
                let feed = Feed(title: "feed", url: NSURL(string: "https://example.com/feed"), summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                var updatedFeed: Feed? = nil

                beforeEach {
                    dataService.feeds = [feed]

                    updatedFeed = nil
                    subject.updateFeed(feed) { updatedFeed = $0 }
                }

                it("should make a call to download the feed URL") {
                    expect(urlSession.lastURL) == feed.url
                    expect(urlSession.lastDownloadTask?.originalRequest?.URL) == feed.url
                }

                context("when the download completes") {
                    beforeEach {
                        guard urlSession.lastDownloadTask != nil else { fail(); return }
                        let location = NSBundle(forClass: self.classForCoder).URLForResource("feed", withExtension: "rss")!
                        urlSessionDelegate.URLSession(urlSession, downloadTask: urlSession.lastDownloadTask!, didFinishDownloadingToURL: location)
                    }

                    it("should call the callback with the updated feed") {
                        expect(updatedFeed?.title) == "Iotlist"
                        expect(updatedFeed?.summary) == "The list for the Internet of Things"
                        expect(updatedFeed?.articlesArray).toNot(beEmpty())
                    }
                }
            }
        }
    }
}

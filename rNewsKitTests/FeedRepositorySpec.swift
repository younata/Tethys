import Quick
import Nimble
@testable import rNewsKit

class DatabaseUseCaseSpec: QuickSpec {
    override func spec() {
        var subject: FakeDatabaseUseCase!
        let feeds = [
            Feed(title: "1", url: nil, summary: "", query: nil, tags: ["a", "b", "c", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            Feed(title: "2", url: nil, summary: "", query: nil, tags: ["b", "d"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            Feed(title: "3", url: nil, summary: "", query: nil, tags: ["dad"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            Feed(title: "4", url: nil, summary: "", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
        ]

        let article1 = Article(title: "b", link: NSURL(string: "https://example.com/article1.html"),
                           summary: "<p>Hello world!</p>", authors: [], published: NSDate(), updatedAt: nil, identifier: "article1",
                           content: "", read: false, estimatedReadingTime: 0, feed: feeds[0], flags: [], enclosures: [])

        let article2 = Article(title: "c", link: NSURL(string: "https://example.com/article2.html"),
                           summary: "<p>Hello world!</p>", authors: [], published: NSDate(), updatedAt: nil, identifier: "article2",
                           content: "", read: true, estimatedReadingTime: 0, feed: feeds[0], flags: [], enclosures: [])


        beforeEach {
            subject = FakeDatabaseUseCase()
        }

        describe("feedsMatchingTag:") {
            var calledHandler = false
            var calledFeeds: [Feed] = []

            beforeEach {
                calledHandler = false
            }

            context("without a tag") {
                it("should return all the feeds when nil tag is given") {
                    subject.feedsMatchingTag(nil) {
                        calledHandler = true
                        calledFeeds = $0
                    }

                    subject.feedsCallback?(feeds)

                    expect(calledHandler) == true
                    expect(calledFeeds).to(equal(feeds))
                }

                it("should return all the feeds when empty string is given as the tag") {
                    subject.feedsMatchingTag("") {
                        calledHandler = true
                        calledFeeds = $0
                    }
                    subject.feedsCallback?(feeds)
                    expect(calledFeeds).to(equal(feeds))
                }
            }

            it("should return feeds that partially match a tag") {
                subject.feedsMatchingTag("a") {
                    calledHandler = true
                    calledFeeds = $0
                }
                subject.feedsCallback?(feeds)
                expect(calledFeeds) == [feeds[0], feeds[2]]
            }
        }
    }
}
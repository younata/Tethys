import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP
import Foundation

@testable import TethysKit

final class InoreaderArticleServiceSpec: QuickSpec {
    override func spec() {
        var subject: InoreaderArticleService!
        var httpClient: FakeHTTPClient!

        let baseURL = URL(string: "https://example.com")!

        beforeEach {
            httpClient = FakeHTTPClient()

            subject = InoreaderArticleService(httpClient: httpClient, baseURL: baseURL)
        }

        describe("-mark(article:asRead:)") {
            it("fails") {
                fail("implement me!")
            }
        }

        describe("-remove(article:)") {
            it("removes the article") {
                fail("implement me!")
            }
        }

        describe("-authors(of:)") {
            articleService_authors_returnsTheAuthors { subject }
        }

        describe("-date(for:)") {
            it("returns the updated time if it was specified") {
                let article = articleFactory(published: Date(timeIntervalSince1970: 0),
                                             updated: Date(timeIntervalSince1970: 1000))
                expect(subject.date(for: article)).to(equal(Date(timeIntervalSince1970: 1000)))
            }

            it("returns the published date if updated wasn't specified") {
                let article = articleFactory(published: Date(timeIntervalSince1970: 100),
                                             updated: nil)
                expect(subject.date(for: article)).to(equal(Date(timeIntervalSince1970: 100)))
            }
        }

        describe("-estimatedReadingTime(of:)") {
            it("calculates it dynamically based on the article's content and a 200 pwm reading speed") {
                let body = (0..<250).map { _ in "foo " }.reduce("", +)
                let article = articleFactory(content: "<html><body>" + body + "</body></html>")
                expect(subject.estimatedReadingTime(of: article)).to(beCloseTo(75))
            }
        }
    }
}

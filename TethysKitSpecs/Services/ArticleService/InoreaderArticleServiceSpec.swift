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
            var future: Future<Result<Article, TethysError>>!
            var article: Article!

            beforeEach {
                article = articleFactory(title: "test", identifier: "some_id")
            }

            context("with asRead being true") {
                let url = URL(string: "https://example.com/reader/api/0/edit-tag?a=user/state/com.google/read&i=some_id")!
                beforeEach {
                    future = subject.mark(article: article, asRead: true)
                }

                it("makes a request to update the article's tag to include marked as read") {
                    expect(httpClient.requests).to(haveCount(1))
                    expect(httpClient.requests.last?.url).to(equal(url))
                    expect(httpClient.requests.last?.httpMethod).to(equal("POST"))
                }

                describe("when the request succeeds") {
                    beforeEach {
                        article.read = false // to assert that the article got marked as read.
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: Data(),
                            status: .ok,
                            mimeType: "",
                            headers: [:]
                        )))
                    }

                    it("returns the given article, this time with read = true") {
                        let expectedArticle = articleFactory(title: "test", identifier: "some_id", read: true, published: article.published)
                        expect(future.value).toNot(beNil())
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal(expectedArticle))
                    }
                }

                itBehavesLikeTheRequestFailed(url: url, shouldParseData: false, httpClient: { httpClient }, future: { future })
            }

            context("with asRead being false") {
                let url = URL(string: "https://example.com/reader/api/0/edit-tag?r=user/state/com.google/read&i=some_id")!

                beforeEach {
                    future = subject.mark(article: article, asRead: false)
                }

                it("makes a request to update the article's tag to include marked as read") {
                    expect(httpClient.requests).to(haveCount(1))
                    expect(httpClient.requests.last?.url).to(equal(url))
                    expect(httpClient.requests.last?.httpMethod).to(equal("POST"))
                }

                describe("when the request succeeds") {
                    beforeEach {
                        article.read = true // to assert that the article got marked as unread
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: Data(),
                            status: .ok,
                            mimeType: "",
                            headers: [:]
                        )))
                    }

                    it("returns the given article, this time with read = true") {
                        let expectedArticle = articleFactory(title: "test", identifier: "some_id", read: false, published: article.published)
                        expect(future.value).toNot(beNil())
                        expect(future.value?.error).to(beNil())
                        expect(future.value?.value).to(equal(expectedArticle))
                    }
                }

                itBehavesLikeTheRequestFailed(url: url, shouldParseData: false, httpClient: { httpClient }, future: { future })
            }
        }

        describe("-remove(article:)") {
            it("immediately resolves with not supported") {
                let future = subject.remove(article: articleFactory())
                expect(future).to(beResolved())
                expect(future.value?.error).to(equal(.notSupported))
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

            it("returns the published date if it's after the updated date") {
                let article = articleFactory(published: Date(timeIntervalSince1970: 1000),
                                             updated: Date(timeIntervalSince1970: 0))
                expect(subject.date(for: article)).to(equal(Date(timeIntervalSince1970: 1000)))
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

import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP

@testable import TethysKit

private enum SomeError: Error {
    case whatever
}

final class NetworkPagedCollectionSpec: QuickSpec {
    override func spec() {
        var subject: NetworkPagedCollection<String>!
        var httpClient: FakeHTTPClient!

        var pagesRequested: [String?] = []
        var nextPageIndex: String? = nil

        beforeEach {
            pagesRequested = []
            httpClient = FakeHTTPClient()

            subject = NetworkPagedCollection<String>(
                httpClient: httpClient,
                requestFactory: { (pageNumber: String?) -> URLRequest in
                    pagesRequested.append(pageNumber)
                    let number = pageNumber ?? ""
                    return URLRequest(url: URL(string: "https://example.com/\(number)")!)
                },
                dataParser: { (data: Data) throws -> ([String], String?) in
                    guard let contents = String(data: data, encoding: .utf8) else {
                        throw SomeError.whatever
                    }
                    return (contents.components(separatedBy: ","), nextPageIndex)
                }
            )
        }

        it("immediately makes a request using the number given") {
            expect(httpClient.requests).to(haveCount(1))
            expect(httpClient.requests.last).to(equal(URLRequest(url: URL(string: "https://example.com/")!)))
            expect(pagesRequested).to(equal([nil]))
        }

        func theCommonCollectionProperties(startIndex: NetworkPagedIndex, endIndex: NetworkPagedIndex, underestimatedCount: Int, line: UInt = #line) {
            describe("asking for common collection properties at this point") {
                it("startIndex") {
                    expect(subject.startIndex, line: line).to(equal(startIndex))
                }

                it("endIndex") {
                    expect(subject.endIndex, line: line).to(equal(endIndex))
                }

                it("underestimatedCount") {
                    expect(subject.underestimatedCount, line: line).to(equal(underestimatedCount))
                }
            }
        }

        theCommonCollectionProperties(startIndex: 0, endIndex: NetworkPagedIndex(actualIndex: 0, isIndefiniteEnd: true), underestimatedCount: 0)

        it("converts to anycollection without hanging") {
            expect(AnyCollection(subject)).toNot(beNil())
        }

        describe("when the request succeeds with valid data") {
            beforeEach {
                nextPageIndex = "2"
                httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                    body: "foo,bar,baz,qux".data(using: .utf8)!,
                    status: .ok,
                    mimeType: "Text/Plain",
                    headers: [:]
                )))
            }

            it("doesn't yet make another request") {
                expect(httpClient.requests).to(haveCount(1))
                expect(httpClient.requests.last).to(equal(URLRequest(url: URL(string: "https://example.com/")!)))
                expect(pagesRequested).to(equal([nil]))
            }

            theCommonCollectionProperties(startIndex: 0, endIndex: NetworkPagedIndex(actualIndex: 4, isIndefiniteEnd: true), underestimatedCount: 4)

            it("converts to anycollection without hanging") {
                expect(AnyCollection(subject)).toNot(beNil())
            }

            it("makes another request when you reach the 75% point on the iteration/access") {
                guard subject.underestimatedCount >= 3 else {
                    fail("not enough items loaded yet")
                    return
                }
                expect(subject[0]).to(equal("foo"))
                expect(httpClient.requests).to(haveCount(1))

                expect(subject[1]).to(equal("bar"))
                expect(httpClient.requests).to(haveCount(1))

                expect(subject[2]).to(equal("baz")) // the 75% point
                expect(httpClient.requests).to(haveCount(2))
                expect(httpClient.requests.last).to(equal(URLRequest(url: URL(string: "https://example.com/2")!)))
                expect(pagesRequested).to(equal([nil, "2"]))
            }

            it("doesn't make multiple requests for the same data point") {
                guard subject.underestimatedCount >= 4 else {
                    fail("not enough items loaded yet")
                    return
                }
                expect(subject[3]).to(equal("qux"))
                expect(httpClient.requests).to(haveCount(2))

                expect(subject[2]).to(equal("baz"))
                expect(httpClient.requests).to(haveCount(2))
            }

            describe("if this next request succeeds with a next page") {
                beforeEach {
                    nextPageIndex = "3"

                    guard httpClient.requestCallCount == 1 else { return }

                    _ = subject[3]

                    httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: "a,b,c,d".data(using: .utf8)!,
                        status: .ok,
                        mimeType: "Text/Plain",
                        headers: [:]
                    )))
                }

                it("doesn't yet request the third page") {
                    expect(httpClient.requests).to(haveCount(2))
                    expect(pagesRequested).to(equal([nil, "2"]))
                }

                theCommonCollectionProperties(startIndex: 0, endIndex: NetworkPagedIndex(actualIndex: 8, isIndefiniteEnd: true), underestimatedCount: 8)

                it("converts to anycollection without hanging") {
                    expect(AnyCollection(subject)).toNot(beNil())
                }

                it("doesn't re-request data it already has") {
                    _ = subject[2]
                    expect(httpClient.requests).to(haveCount(2))
                }

                it("makes another request when you reach the 75% point on the iteration/access for THIS requested data") {
                    guard subject.underestimatedCount >= 7 else {
                        fail("not enough items loaded yet")
                        return
                    }
                    expect(subject[4]).to(equal("a"))
                    expect(httpClient.requests).to(haveCount(2))

                    expect(subject[5]).to(equal("b"))
                    expect(httpClient.requests).to(haveCount(2))

                    expect(subject[6]).to(equal("c")) // the 75% point (index 6, as opposed to index 5 for 75% of entire data set).
                    expect(httpClient.requests).to(haveCount(3))
                    expect(httpClient.requests.last).to(equal(URLRequest(url: URL(string: "https://example.com/3")!)))
                    expect(pagesRequested).to(equal([nil, "2", "3"]))
                }

                it("doesn't make multiple requests for the same data point") {
                    guard subject.underestimatedCount >= 8 else {
                        fail("not enough items loaded yet")
                        return
                    }
                    expect(subject[7]).to(equal("d"))
                    expect(httpClient.requests).to(haveCount(3))

                    expect(subject[6]).to(equal("c"))
                    expect(httpClient.requests).to(haveCount(3))
                }
            }

            describe("if this request succeeds with no next page") {
                beforeEach {
                    nextPageIndex = nil

                    guard httpClient.requestCallCount == 1 else { return }

                    _ = subject[3]

                    httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: "a,b,c,d".data(using: .utf8)!,
                        status: .ok,
                        mimeType: "Text/Plain",
                        headers: [:]
                    )))
                }

                it("doesn't request the third data, even when the entire collection is iterated through") {
                    expect(httpClient.requests).to(haveCount(2))
                    guard httpClient.requestCallCount == 2 else {
                        fail("Expected to have made 2 requests")
                        return
                    }
                    expect(pagesRequested).to(equal([nil, "2"]))
                    expect(Array(subject)).to(equal(["foo", "bar", "baz", "qux", "a", "b", "c", "d"]))
                    expect(httpClient.requests).to(haveCount(2))
                    expect(pagesRequested).to(equal([nil, "2"]))
                }

                theCommonCollectionProperties(startIndex: 0, endIndex: NetworkPagedIndex(actualIndex: 8, isIndefiniteEnd: false), underestimatedCount: 8)

                it("converts to anycollection without hanging") {
                    expect(AnyCollection(subject)).to(haveCount(8))
                    expect(Array(AnyCollection(subject))).to(equal(["foo", "bar", "baz", "qux", "a", "b", "c", "d"]))
                }
            }
        }
    }
}

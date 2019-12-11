import Quick
import Nimble
import CBGPromise
import TethysKit
import FutureHTTP

func itCachesInProgressFutures<T>(factory: @escaping () -> Future<Result<T, TethysError>>,
                                  callChecker: @escaping (Int) -> Void,
                                  resolver: @escaping (TethysError?) -> Result<T, TethysError>,
                                  equator: @escaping (Result<T, TethysError>, Result<T, TethysError>) -> Void) {
    var future: Future<Result<T, TethysError>>!

    beforeEach {
        future = factory()
    }

    it("returns an in-progress future") {
        expect(future).toNot(beResolved())
    }

    it("makes a call to the underlying service") {
        callChecker(1)
    }

    it("does not make another call to the underlying service if called before that future resolves") {
        _ = factory()
        callChecker(1)
    }

    describe("on success") {
        var expectedValue: Result<T, TethysError>!
        beforeEach {
            expectedValue = resolver(nil)
        }

        it("resolves the future with the error") {
            expect(future.value).toNot(beNil())

            guard let received = future.value else { return }
            equator(received, expectedValue)
        }

        describe("if called again") {
            beforeEach {
                future = factory()
            }

            it("returns an in-progress future") {
                expect(future).toNot(beResolved())
            }

            it("makes another call to the underlying service") {
                callChecker(2)
            }
        }
    }

    describe("on error") {
        var expectedValue: Result<T, TethysError>!
        beforeEach {
            expectedValue = resolver(TethysError.unknown)
        }

        it("resolves the future with the error") {
            expect(future.value?.error).to(equal(expectedValue.error))
        }

        describe("if called again") {
            beforeEach {
                future = factory()
            }

            it("returns an in-progress future") {
                expect(future).toNot(beResolved())
            }

            it("makes another call to the underlying service") {
                callChecker(2)
            }
        }
    }
}

func itBehavesLikeTheRequestFailed<T>(url: URL, shouldParseData: Bool = true, file: String = #file, line: UInt = #line,
                                      httpClient: @escaping () -> FakeHTTPClient,
                                      future: @escaping () -> Future<Result<T, TethysError>>) {
    if T.self != Void.self && shouldParseData {
        describe("when the request succeeds") {
            context("and the data is not valid") {
                beforeEach {
                    guard httpClient().requestPromises.last?.future.value == nil else {
                        fail("most recent promise was already resolved", file: file, line: line)
                        return
                    }
                    httpClient().requestPromises.last?.resolve(.success(HTTPResponse(
                        body: "[\"bad\": \"data\"]".data(using: .utf8)!,
                        status: .ok,
                        mimeType: "Application/JSON",
                        headers: [:]
                    )))
                }

                it("resolves the future with a bad response error") {
                    expect(future().value, file: file, line: line).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future().value?.error, file: file, line: line).to(equal(TethysError.network(url, .badResponse)))
                }
            }
        }
    }

    describe("when the request fails") {
        context("when the request fails with a 400 level error") {
            beforeEach {
                guard httpClient().requestPromises.last?.future.value == nil else {
                    fail("most recent promise was already resolved", file: file, line: line)
                    return
                }
                httpClient().requestPromises.last?.resolve(.success(HTTPResponse(
                    body: "403".data(using: .utf8)!,
                    status: HTTPStatus.init(rawValue: 403)!,
                    mimeType: "Application/JSON",
                    headers: [:]
                )))
            }

            it("resolves the future with the error") {
                expect(future().value, file: file, line: line).toNot(beNil(), description: "Expected future to be resolved")
                expect(future().value?.error, file: file, line: line).to(equal(
                    TethysError.network(url, .http(.forbidden, "403".data(using: .utf8)!))
                ))
            }
        }

        context("when the request fails with a 500 level error") {
            beforeEach {
                guard httpClient().requestPromises.last?.future.value == nil else {
                    fail("most recent promise was already resolved", file: file, line: line)
                    return
                }
                httpClient().requestPromises.last?.resolve(.success(HTTPResponse(
                    body: "502".data(using: .utf8)!,
                    status: HTTPStatus.init(rawValue: 502)!,
                    mimeType: "Application/JSON",
                    headers: [:]
                )))
            }

            it("resolves the future with the error") {
                expect(future().value, file: file, line: line).toNot(beNil(), description: "Expected future to be resolved")
                expect(future().value?.error, file: file, line: line).to(equal(
                    TethysError.network(url, .http(.badGateway, "502".data(using: .utf8)!))
                ))
            }
        }

        context("when the request fails with an error") {
            beforeEach {
                guard httpClient().requestPromises.last?.future.value == nil else {
                    fail("most recent promise was already resolved", file: file, line: line)
                    return
                }
                httpClient().requestPromises.last?.resolve(.failure(HTTPClientError.network(.timedOut)))
            }

            it("resolves the future with an error") {
                expect(future().value, file: file, line: line).toNot(beNil(), description: "Expected future to be resolved")
                expect(future().value?.error, file: file, line: line).to(equal(
                    TethysError.network(url, .timedOut)
                ))
            }
        }
    }
}

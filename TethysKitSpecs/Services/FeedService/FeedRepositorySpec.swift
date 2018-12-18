import Quick
import Nimble
import Result
import CBGPromise

@testable import TethysKit

final class FeedRepositorySpec: QuickSpec {
    override func spec() {
        var subject: FeedRepository!

        var feedService: FakeFeedService!

        beforeEach {
            feedService = FakeFeedService()

            subject = FeedRepository(feedService: feedService)
        }

        describe("feeds()") {
            itCachesInProgressFutures(
                factory: { subject.feeds() },
                callChecker: { expect(feedService.feedsPromises).to(haveCount($0)) },
                resolver: { error -> Result<AnyCollection<Feed>, TethysError> in
                    let result = resultFactory(error: error, value: AnyCollection([feedFactory(), feedFactory()]))
                    feedService.feedsPromises.last?.resolve(result)
                    return result
                },
                equator: collectionComparator
            )
        }

        describe("articles(of:)") {
            let feed = feedFactory()
            itCachesInProgressFutures(
                factory: { subject.articles(of: feed) },
                callChecker: { expect(feedService.articlesOfFeedCalls).to(haveCount($0)) },
                resolver: { error -> Result<AnyCollection<Article>, TethysError> in
                    let result = resultFactory(error: error, value: AnyCollection([articleFactory(), articleFactory()]))
                    feedService.articlesOfFeedPromises.last?.resolve(result)
                    return result
                },
                equator: collectionComparator
            )
        }

        describe("subscribe(to:") {
            let url = URL(string: "https://example.com")!

            itCachesInProgressFutures(
                factory: { subject.subscribe(to: url) },
                callChecker: { expect(feedService.subscribeCalls).to(haveCount($0)) },
                resolver: { error -> Result<Feed, TethysError> in
                    let result = resultFactory(error: error, value: feedFactory())
                    feedService.subscribePromises.last?.resolve(result)
                    return result
                },
                equator: equatableComparator
            )
        }

        describe("tags()") {
            itCachesInProgressFutures(
                factory: { subject.tags() },
                callChecker: { expect(feedService.tagsPromises).to(haveCount($0)) },
                resolver: { error -> Result<AnyCollection<String>, TethysError> in
                    let result = resultFactory(error: error, value: AnyCollection(["foo", "bar"]))
                    feedService.tagsPromises.last?.resolve(result)
                    return result
                },
                equator: collectionComparator
            )
        }

        describe("set(tags:of:)") {
            let tags = ["foo", "bar", "baz"]
            let feed = feedFactory()

            itCachesInProgressFutures(
                factory: { subject.set(tags: tags, of: feed) },
                callChecker: { expect(feedService.setTagsCalls).to(haveCount($0)) },
                resolver: { error -> Result<Feed, TethysError> in
                    let result = resultFactory(error: error, value: feedFactory())
                    feedService.setTagsPromises.last?.resolve(result)
                    return result
                },
                equator: equatableComparator
            )
        }

        describe("set(tags:on:)") {
            let url = URL(string: "https://example.com")!
            let feed = feedFactory()

            itCachesInProgressFutures(
                factory: { subject.set(url: url, on: feed) },
                callChecker: { expect(feedService.setURLCalls).to(haveCount($0)) },
                resolver: { error -> Result<Feed, TethysError> in
                    let result = resultFactory(error: error, value: feedFactory())
                    feedService.setURLPromises.last?.resolve(result)
                    return result
                },
                equator: equatableComparator
            )
        }

        describe("readAll(of:)") {
            let feed = feedFactory()

            itCachesInProgressFutures(
                factory: { subject.readAll(of: feed) },
                callChecker: { expect(feedService.readAllOfFeedCalls).to(haveCount($0)) },
                resolver: { error -> Result<Void, TethysError> in
                    let result: Result<Void, TethysError> = voidResult(error: error)
                    feedService.readAllOfFeedPromises.last?.resolve(result)
                    return result
                },
                equator: { expected, _ in expect(expected.value).to(beVoid()) }
            )
        }

        describe("readAll(of:)") {
            let feed = feedFactory()

            itCachesInProgressFutures(
                factory: { subject.remove(feed: feed) },
                callChecker: { expect(feedService.removeFeedCalls).to(haveCount($0)) },
                resolver: { error -> Result<Void, TethysError> in
                    let result = voidResult(error: error)
                    feedService.removeFeedPromises.last?.resolve(result)
                    return result
                },
                equator: { expected, _ in expect(expected.value).to(beVoid()) }
            )
        }
    }
}

func itCachesInProgressFutures<T>(factory: @escaping () -> Future<Result<T, TethysError>>,
                                  callChecker: @escaping (Int) -> Void,
                                  resolver: @escaping (TethysError?) -> Result<T, TethysError>,
                                  equator: @escaping (Result<T, TethysError>, Result<T, TethysError>) -> Void) {
    var future: Future<Result<T, TethysError>>!

    beforeEach {
        future = factory()
    }

    it("returns an in-progress future") {
        expect(future.value).to(beNil())
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
                expect(future.value).to(beNil())
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
                expect(future.value).to(beNil())
            }

            it("makes another call to the underlying service") {
                callChecker(2)
            }
        }
    }
}

func collectionComparator<T: Equatable>(receivedResult: Result<AnyCollection<T>, TethysError>,
                                        expectedResult: Result<AnyCollection<T>, TethysError>) {
    guard let received = receivedResult.value, let expected = expectedResult.value else {
        fail("Expected received and expected to not be nil, got \(String(describing: receivedResult)) and \(String(describing: expectedResult))")
        return
    }

    expect(Array(received)).to(equal(Array(expected)))
}

func equatableComparator<T: Equatable>(received: Result<T, TethysError>,
                                       expected: Result<T, TethysError>) {
    expect(received.value).to(equal(expected.value))
}

func resultFactory<T>(error: TethysError?, value: T) -> Result<T, TethysError> {
    let result: Result<T, TethysError>
    if let error = error {
        result = .failure(error)
    } else {
        result = .success(value)
    }
    return result
}

func voidResult(error: TethysError?) -> Result<Void, TethysError> {
    if let error = error {
        return .failure(error)
    } else {
        return .success(Void())
    }
}

import Quick
import Nimble
import Result
import CBGPromise

@testable import TethysKit

final class ArticleRepositorySpec: QuickSpec {
    override func spec() {
        var subject: ArticleRepository!

        var articleService: FakeArticleService!

        let article = articleFactory()

        beforeEach {
            articleService = FakeArticleService()

            subject = ArticleRepository(articleService: articleService)
        }

        describe("mark(article:asRead:)") {
            itCachesInProgressFutures(
                factory: { return subject.mark(article: article, asRead: true) },
                callChecker: { expect(articleService.markArticleAsReadCalls).to(haveCount($0)) },
                resolver: { error -> Result<Article, TethysError> in
                    let result = resultFactory(error: error, value: articleFactory())
                    articleService.markArticleAsReadPromises.last?.resolve(result)
                    return result
                },
                equator: equatableComparator
            )
        }

        describe("remove(article:)") {
            itCachesInProgressFutures(
                factory: { subject.remove(article: article) },
                callChecker: { expect(articleService.removeArticleCalls).to(haveCount($0)) },
                resolver: { error -> Result<Void, TethysError> in
                    let result = voidResult(error: error)
                    articleService.removeArticlePromises.last?.resolve(result)
                    return result
                },
                equator: { expected, _ in expect(expected.value).to(beVoid()) }
            )
        }

        describe("authors(of:)") {
            beforeEach {
                articleService.authorStub[article] = "an author"
            }

            itCachesValuesPermanently(
                factory: { return subject.authors(of: article) },
                callChecker: { expect(articleService.authorsCalls).to(haveCount($0)) },
                expected: { return "an author" }
            )
        }

        describe("date(for:)") {
            let date = Date()
            beforeEach {
                articleService.dateForArticleStub[article] = date
            }

            itCachesValuesPermanently(
                factory: { return subject.date(for: article) },
                callChecker: { expect(articleService.dateForArticleCalls).to(haveCount($0)) },
                expected: { return date }
            )
        }

        describe("estimatedReadingTime(of:)") {
            beforeEach {
                articleService.estimatedReadingTimeStub[article] = TimeInterval(124)
            }

            itCachesValuesPermanently(
                factory: { return subject.estimatedReadingTime(of: article) },
                callChecker: { expect(articleService.estimatedReadingTimeCalls).to(haveCount($0)) },
                expected: { return TimeInterval(124) }
            )
        }
    }
}

func itCachesFuturesPermanently<T>(factory: @escaping () -> Future<Result<T, TethysError>>,
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

            it("returns the resolved future") {
                expect(future.value).toNot(beNil())

                guard let received = future.value else { return }
                equator(received, expectedValue)
            }

            it("does not make another call to the underlying service") {
                callChecker(1)
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

func itCachesValuesPermanently<T: Equatable>(factory: @escaping () -> T,
                                             callChecker: @escaping (Int) -> Void,
                                             expected: @escaping () -> T) {
    var value: T!

    beforeEach {
        value = factory()
    }

    it("returns the expected value") {
        expect(value).to(equal(expected()))
    }

    it("makes a call to the underlying service") {
        callChecker(1)
    }

    it("does not make another call to the underlying service if called again") {
        _ = factory()
        callChecker(1)
    }
}

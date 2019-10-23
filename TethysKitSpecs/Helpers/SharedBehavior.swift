import Quick
import Nimble
import CBGPromise
import TethysKit

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

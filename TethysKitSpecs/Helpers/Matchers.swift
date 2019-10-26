import Quick
import Nimble
import TethysKit

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

import CBGPromise

func beResolved<T>() -> Predicate<Future<T>> {
    return Predicate { (received: Expression<Future<T>>) throws -> PredicateResult in
        let msg = ExpectationMessage.expectedActualValueTo("be resolved")
        if let receivedFuture = try received.evaluate() {
            return PredicateResult(bool: receivedFuture.value != nil, message: msg)
        } else {
            return PredicateResult(status: .fail, message: msg.appendedBeNilHint())
        }
    }
}

final class MatcherSpec: QuickSpec {
    override func spec() {
        enum SomeError: Error {
            case woot
            case boo
        }

        enum SomeSuccess {
            case whee
        }

        describe("beResolved()") {
            it("does not match if the future is not resolved") {
                let promise = Promise<Void>()

                expect(promise.future).toNot(beResolved())
            }

            it("matches if the future is resolved") {
                let promise = Promise<Void>()
                promise.resolve(Void())

                expect(promise.future).to(beResolved())
            }
        }
    }
}

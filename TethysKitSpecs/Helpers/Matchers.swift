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

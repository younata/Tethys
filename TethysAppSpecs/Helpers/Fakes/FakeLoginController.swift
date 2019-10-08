import Result
import CBGPromise
import TethysKit

@testable import Tethys

final class FakeLoginController: LoginController {
    var window: UIWindow? = nil

    private(set) var beginPromises: [Promise<Result<Account, TethysError>>] = []
    func begin() -> Future<Result<Account, TethysError>> {
        let promise = Promise<Result<Account, TethysError>>()
        self.beginPromises.append(promise)
        return promise.future
    }
}

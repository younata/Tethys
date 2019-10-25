import Result
import CBGPromise

import TethysKit

final class FakeAccountService: AccountService {
    private(set) var accountsPromises: [Promise<[Result<Account, TethysError>]>] = []
    func accounts() -> Future<[Result<Account, TethysError>]> {
        let promise = Promise<[Result<Account, TethysError>]>()
        self.accountsPromises.append(promise)
        return promise.future
    }

    private(set) var authenticateCalls: [String] = []
    private(set) var authenticatePromises: [Promise<Result<Account, TethysError>>] = []
    func authenticate(code: String) -> Future<Result<Account, TethysError>> {
        self.authenticateCalls.append(code)
        let promise = Promise<Result<Account, TethysError>>()
        self.authenticatePromises.append(promise)
        return promise.future
    }

    private(set) var logoutCalls: [Account] = []
    private(set) var logoutPromises: [Promise<Result<Void, TethysError>>] = []
    func logout(of account: Account) -> Future<Result<Void, TethysError>> {
        let promise = Promise<Result<Void, TethysError>>()
        logoutCalls.append(account)
        logoutPromises.append(promise)
        return promise.future
    }
}

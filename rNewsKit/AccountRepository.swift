import CBGPromise
import Result
import Sinope

public protocol AccountRepository {
    func login(email: String, password: String) -> Future<Result<Void, RNewsError>>
    func register(email: String, password: String) -> Future<Result<Void, RNewsError>>
    func loggedIn() -> Bool
}

protocol AccountRepositoryDelegate {
    func accountRepositoryDidLogIn(accountRepository: AccountRepository)
}

protocol InternalAccountRepository: AccountRepository {
    var delegate: AccountRepositoryDelegate? { get set }

    func backendRepository() -> Sinope.Repository?
}

private let pasiphae_token = "pasiphae_token"

final class DefaultAccountRepository: InternalAccountRepository {
    private let repository: Sinope.Repository
    private let userDefaults: NSUserDefaults

    var delegate: AccountRepositoryDelegate?

    init(repository: Sinope.Repository, userDefaults: NSUserDefaults) {
        self.repository = repository
        self.userDefaults = userDefaults

        if let token = self.userDefaults.stringForKey(pasiphae_token) {
            self.repository.login(token)
        }
    }

    // MARK: AccountRepository
    func login(email: String, password: String) -> Future<Result<Void, RNewsError>> {
        return self.repository.login(email, password: password).map { res -> Result<Void, RNewsError> in
            switch res {
            case .Success():
                self.userDefaults.setValue(self.repository.authToken ?? "", forKey: pasiphae_token)
                self.delegate?.accountRepositoryDidLogIn(self)
                return Result.Success()
            case let .Failure(error):
                return Result.Failure(RNewsError.Backend(error))
            }
        }
    }

    func register(email: String, password: String) -> Future<Result<Void, RNewsError>> {
        return self.repository.createAccount(email, password: password).map { res -> Result<Void, RNewsError> in
            switch res {
            case .Success():
                self.userDefaults.setValue(self.repository.authToken ?? "", forKey: pasiphae_token)
                self.delegate?.accountRepositoryDidLogIn(self)
                return Result.Success()
            case let .Failure(error):
                return Result.Failure(RNewsError.Backend(error))
            }
        }
    }

    func loggedIn() -> Bool {
        return self.userDefaults.stringForKey(pasiphae_token) != nil
    }

    // MARK: InternalAccountRepository

    func backendRepository() -> Sinope.Repository? {
        if self.loggedIn() {
            return self.repository
        }
        return nil
    }
}

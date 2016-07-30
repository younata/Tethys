import CBGPromise
import Result
import Sinope

public protocol AccountRepository: class {
    func login(email: String, password: String) -> Future<Result<Void, RNewsError>>
    func register(email: String, password: String) -> Future<Result<Void, RNewsError>>
    func loggedIn() -> String?
    func logOut()
}

protocol AccountRepositoryDelegate {
    func accountRepositoryDidLogIn(accountRepository: InternalAccountRepository)
}

protocol InternalAccountRepository: AccountRepository {
    var delegate: AccountRepositoryDelegate? { get set }

    func backendRepository() -> Sinope.Repository?
}

private let pasiphae_token = "pasiphae_token"
private let pasiphae_login = "pasiphae_login"

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
                self.userDefaults.setValue(email, forKey: pasiphae_login)
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
                self.userDefaults.setValue(email, forKey: pasiphae_login)
                self.delegate?.accountRepositoryDidLogIn(self)
                return Result.Success()
            case let .Failure(error):
                return Result.Failure(RNewsError.Backend(error))
            }
        }
    }

    func loggedIn() -> String? {
        if self.userDefaults.stringForKey(pasiphae_token) != nil {
            return self.userDefaults.stringForKey(pasiphae_login)
        }
        return nil
    }

    func logOut() {
        self.userDefaults.removeObjectForKey(pasiphae_token)
        self.userDefaults.removeObjectForKey(pasiphae_login)
    }

    // MARK: InternalAccountRepository

    func backendRepository() -> Sinope.Repository? {
        if self.loggedIn() != nil {
            return self.repository
        }
        return nil
    }
}

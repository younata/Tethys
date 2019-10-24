import Result
import CBGPromise
import FutureHTTP

public enum AccountType: String, Codable {
    case inoreader
}

struct Credential: Codable, Equatable, Hashable {
    let access: String
    let expiration: Date
    let refresh: String
    let accountId: String
    let accountType: AccountType

    func authorization() -> String {
        return "Bearer \(self.access)"
    }
}

public struct Account: Codable, Equatable {
    public let kind: AccountType
    public let username: String
    public let id: String
}

public protocol AccountService {
    func accounts() -> Future<[Result<Account, TethysError>]>
    func authenticate(code: String) -> Future<Result<Account, TethysError>>
}

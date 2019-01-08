import Result
import CBGPromise
import FutureHTTP
import SwiftKeychainWrapper

protocol CredentialService {
    func credentials() -> Future<Result<[Credential], TethysError>>
    func store(credential: Credential) -> Future<Result<Void, TethysError>>
    func delete(credential: Credential) -> Future<Result<Void, TethysError>>
}

private let credentialKey = "credentials"

struct KeychainCredentialService: CredentialService {
    let keychain: KeychainWrapper

    func credentials() -> Future<Result<[Credential], TethysError>> {
        guard let data = self.keychain.data(forKey: credentialKey) else {
            return Promise<Result<[Credential], TethysError>>.resolved(.success([]))
        }
        do {
            let results = try JSONDecoder().decode([Credential].self, from: data)
            return Promise<Result<[Credential], TethysError>>.resolved(.success(results))
        } catch let error {
            dump(error)
            return Promise<Result<[Credential], TethysError>>.resolved(.failure(.database(.unknown)))
        }
    }

    func store(credential: Credential) -> Future<Result<Void, TethysError>> {
        return self.credentials().map { result -> Result<Void, TethysError> in
            switch result {
            case .failure(let error):
                return .failure(error)
            case .success(var credentials):
                credentials.removeAll(where: { $0.accountId == credential.accountId })
                credentials.append(credential)

                do {
                    let data = try JSONEncoder().encode(credentials)
                    _ = self.keychain.set(data, forKey: credentialKey)
                    return .success(Void())
                } catch let error {
                    dump(error)
                    return .failure(.database(.unknown))
                }
            }
        }
    }

    func delete(credential: Credential) -> Future<Result<Void, TethysError>> {
        return self.credentials().map { result -> Result<Void, TethysError> in
            switch result {
            case .failure(let error):
                return .failure(error)
            case .success(var credentials):
                credentials.removeAll(where: { $0.accountId == credential.accountId })

                do {
                    let data = try JSONEncoder().encode(credentials)
                    _ = self.keychain.set(data, forKey: credentialKey)
                    return .success(Void())
                } catch let error {
                    dump(error)
                    return .failure(.database(.unknown))
                }
            }
        }
    }
}

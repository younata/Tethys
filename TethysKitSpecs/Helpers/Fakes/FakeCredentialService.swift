import Result
import CBGPromise

@testable import TethysKit

final class FakeCredentialService: CredentialService {
    private(set) var credentialsPromises: [Promise<Result<[Credential], TethysError>>] = []
    func credentials() -> Future<Result<[Credential], TethysError>> {
        let promise = Promise<Result<[Credential], TethysError>>()
        self.credentialsPromises.append(promise)
        return promise.future
    }

    private(set) var storeCredentialCalls: [Credential] = []
    private(set) var storeCredentialPromises: [Promise<Result<Void, TethysError>>] = []
    func store(credential: Credential) -> Future<Result<Void, TethysError>> {
        self.storeCredentialCalls.append(credential)
        let promise = Promise<Result<Void, TethysError>>()
        self.storeCredentialPromises.append(promise)
        return promise.future
    }

    private(set) var deleteCredentialCalls: [Credential] = []
    private(set) var deleteCredentialPromises: [Promise<Result<Void, TethysError>>] = []
    func delete(credential: Credential) -> Future<Result<Void, TethysError>> {
        self.deleteCredentialCalls.append(credential)
        let promise = Promise<Result<Void, TethysError>>()
        self.deleteCredentialPromises.append(promise)
        return promise.future
    }
}

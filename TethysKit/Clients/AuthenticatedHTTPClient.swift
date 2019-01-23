import Result
import CBGPromise
import FutureHTTP

private enum CredentialResponse {
    case exists(Credential)
    case other(HTTPResponse)
    case notFound
}

struct AuthenticatedHTTPClient: HTTPClient {
    let client: HTTPClient
    let credentialService: CredentialService
    let refreshURL: URL
    let clientId: String
    let clientSecret: String
    let accountId: String
    let dateOracle: () -> Date

    func request(_ request: URLRequest) -> Future<Result<HTTPResponse, HTTPClientError>> {
        return self.credentialService.credentials().map { result -> CredentialResponse in
            switch result {
            case .success(let credentials):
                guard let credential = credentials.first(where: { $0.accountId == self.accountId }) else {
                    return .notFound
                }

                return .exists(credential)
            case .failure:
                return .notFound
            }
        }.map { credentialResponse -> Future<Result<HTTPResponse, HTTPClientError>> in
            switch credentialResponse {
            case .notFound:
                return Promise<Result<HTTPResponse, HTTPClientError>>.resolved(.success(self.unauthorized))
            case .other(let response):
                return Promise<Result<HTTPResponse, HTTPClientError>>.resolved(.success(response))
            case .exists(let credential):
                guard credential.expiration.timeIntervalSince(self.dateOracle()) < 5 else {
                    return self.make(request: request, credential: credential)
                }

                return self.refresh(credential: credential, originalRequest: request)
            }
        }
    }

    private func make(request: URLRequest, credential: Credential) -> Future<Result<HTTPResponse, HTTPClientError>> {
        var newRequest = request
        newRequest.setValue("Bearer \(credential.access)", forHTTPHeaderField: "Authorization")
        return self.client.request(newRequest).map { result in
            guard let response = result.value, response.status == .unauthorized else {
                return Promise<Result<HTTPResponse, HTTPClientError>>.resolved(result)
            }
            return self.credentialService.delete(credential: credential).map { _ in
                return result
            }
        }
    }

    private func refresh(credential: Credential,
                         originalRequest: URLRequest) -> Future<Result<HTTPResponse, HTTPClientError>> {
        let request = URLRequest(
            url: self.refreshURL,
            headers: ["content-type": "application/x-www-form-urlencoded"],
            method: .post(formData(contents: [
                "client_id": self.clientId,
                "client_secret": self.clientSecret,
                "grant_type": "refresh",
                "refresh_token": credential.refresh
            ]))
        )
        return self.client.request(request).map { result -> Future<Result<CredentialResponse, HTTPClientError>> in
            return result.mapFuture { response in
                guard response.status == .ok else {
                    return self.credentialService.delete(credential: credential).map { _ in
                        return .success(.other(response))
                    }
                }

                do {
                    let credentialResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: response.body)
                    let credential = Credential(
                        access: credentialResponse.access_token,
                        expiration: self.dateOracle().addingTimeInterval(credentialResponse.expires_in),
                        refresh: credentialResponse.refresh_token,
                        accountId: self.accountId,
                        accountType: .inoreader
                    )

                    return self.credentialService.store(credential: credential).map { _ in
                        return .success(.exists(credential))
                    }
                } catch let error {
                    dump(error)
                    return self.credentialService.delete(credential: credential).map { _ in
                        return .success(.notFound)
                    }
                }
            }
        }.map { result -> Future<Result<HTTPResponse, HTTPClientError>> in
            switch result {
            case .failure(let error):
                return Promise<Result<HTTPResponse, HTTPClientError>>.resolved(.failure(error))
            case .success(.notFound):
                return Promise<Result<HTTPResponse, HTTPClientError>>.resolved(.success(self.unauthorized))
            case .success(.other(let response)):
                return Promise<Result<HTTPResponse, HTTPClientError>>.resolved(.success(response))
            case .success(.exists(let credential)):
                return self.make(request: originalRequest, credential: credential)
            }
        }
    }

    private let unauthorized = HTTPResponse(body: Data(), status: .unauthorized, mimeType: "text/plain", headers: [:])
}

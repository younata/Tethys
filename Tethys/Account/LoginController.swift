import UIKit
import Result
import TethysKit
import CBGPromise
import AuthenticationServices

public protocol LoginController {
    func begin() -> Future<Result<Account, TethysError>>
}

public typealias AuthSessionOracle = (
    URL, String?, @escaping ASWebAuthenticationSession.CompletionHandler
    ) -> ASWebAuthenticationSession

public final class OAuthLoginController: LoginController {
    private let accountService: AccountService
    private let mainQueue: OperationQueue
    private let authenticationSessionFactory: AuthSessionOracle

    private var session: ASWebAuthenticationSession? = nil

    public init(accountService: AccountService,
                mainQueue: OperationQueue,
                authenticationSessionFactory: @escaping AuthSessionOracle) {
        self.accountService = accountService
        self.mainQueue = mainQueue
        self.authenticationSessionFactory = authenticationSessionFactory
    }

    public func begin() -> Future<Result<Account, TethysError>> {
        let promise = Promise<Result<Account, TethysError>>()

        var urlComponents = URLComponents(
            url: URL(string: "https://www.inoreader.com/oauth2/auth")!,
            resolvingAgainstBaseURL: false
            )!
        let csrf = UUID().uuidString

        guard let clientId = Bundle.main.infoDictionary?["InoreaderClientID"] as? String, !clientId.isEmpty else {
            fputs("No inoreaderclientid in bundle\n", stderr)
            return Promise<Result<Account, TethysError>>.resolved(.failure(.database(.entryNotFound)))
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: "https://tethys.younata.com/oauth"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read write"),
            URLQueryItem(name: "state", value: csrf)
        ]
        guard let authURL = urlComponents.url else {
            fatalError("Unable to construct URL from \(urlComponents)")
        }
        let callbackUrlScheme = "rnews"

        self.session = self.authenticationSessionFactory(authURL, callbackUrlScheme) {(callback: URL?, error: Error?) in
            guard promise.future.value == nil else { return }
            guard error == nil, let successURL = callback else {
                promise.resolve(.failure(.network(authURL, .cancelled)))
                return
            }

            guard let urlComponents = URLComponents(url: successURL, resolvingAgainstBaseURL: true) else {
                promise.resolve(.failure(.network(authURL, .badResponse)))
                return
            }

            let queryItems = urlComponents.queryItems ?? []

            guard queryItems.contains(URLQueryItem(name: "state", value: csrf)) else {
                promise.resolve(.failure(.network(authURL, .badResponse)))
                return
            }

            guard let oauthToken = urlComponents.queryItems?.first(where: {$0.name == "code"})?.value else {
                promise.resolve(.failure(.network(authURL, .badResponse)))
                return
            }
            self.accountService.authenticate(code: oauthToken).then { result in
                self.mainQueue.addOperation {
                    promise.resolve(result)
                    self.session = nil
                }
            }
        }
        self.session?.start()

        return promise.future
    }
}

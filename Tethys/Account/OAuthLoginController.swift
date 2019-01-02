import UIKit
import AuthenticationServices

public class OAuthLoginController: UIViewController, ThemeRepositorySubscriber {
    private let themeRepository: ThemeRepository

    private(set) var authenticationSession: ASWebAuthenticationSession!

    public init(themeRepository: ThemeRepository) {
        self.themeRepository = themeRepository

        var urlComponents = URLComponents(
            url: URL(string: "https://www.inoreader.com/oauth2/auth")!,
            resolvingAgainstBaseURL: false
        )!
        let csrf = UUID().uuidString
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: Bundle.main.infoDictionary?["InoreaderClientID"] as? String),
            URLQueryItem(name: "redirect_uri", value: "https://tethys.younata.com/oauth"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read write"),
            URLQueryItem(name: "state", value: csrf)
        ]
        guard let authURL = urlComponents.url else {
            fatalError("Unable to construct URL from \(urlComponents)")
        }
        let callbackUrlScheme = "rnews"

        super.init(nibName: nil, bundle: nil)

        self.authenticationSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackUrlScheme,
            completionHandler: { (callBack: URL?, error: Error?) in
                // handle auth response
                guard error == nil, let successURL = callBack else {
                    return
                }

                guard let urlComponents = URLComponents(url: successURL, resolvingAgainstBaseURL: true) else {
                    return
                }

                let queryItems = urlComponents.queryItems ?? []

                guard queryItems.contains(URLQueryItem(name: "state", value: csrf)) else {
                    return
                }

                guard let oauthToken = urlComponents.queryItems?.first(where: {$0.name == "code"})?.value else {
                    return
                }

                let alert = UIAlertController(title: "SUCCESS", message: oauthToken, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "ok", style: .default, handler: { _ in
                    self.navigationController?.popViewController(animated: true)
                }))
                self.present(alert, animated: true, completion: nil)
        })
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        self.authenticationSession.start()
    }

    public func themeRepositoryDidChangeTheme(_ themeRepository: ThemeRepository) {
        self.view.backgroundColor = themeRepository.backgroundColor
    }
}

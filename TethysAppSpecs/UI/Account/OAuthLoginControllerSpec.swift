import Quick
import UIKit
import Nimble

@testable import Tethys

final class OAuthLoginViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: OAuthLoginController!

        var themeRepository: ThemeRepository!

        var rootViewController: UIViewController!
        var navigationController: UINavigationController!

        beforeEach {
            themeRepository = themeRepositoryFactory()

            subject = OAuthLoginController(themeRepository: themeRepository)

            rootViewController = UIViewController()
            navigationController = UINavigationController(rootViewController: rootViewController)
            navigationController.pushViewController(subject, animated: false)

            subject.view.layoutIfNeeded()
        }

        it("starts an authentication session") {
            expect(subject.authenticationSession.began).to(beTrue())
        }

        it("configures the authentication session for inoreader with a custom redirect") {
            let receivedURL = subject.authenticationSession.url

            guard let components = URLComponents(url: receivedURL, resolvingAgainstBaseURL: false) else {
                fail("Unable to construct URLComponents from \(receivedURL)")
                return
            }

            expect(components.scheme).to(equal("https"), description: "Should make a request to an https url")
            expect(components.host).to(equal("www.inoreader.com"), description: "Should make a request to inoreader")
            expect(components.path).to(equal("/oauth2/auth"), description: "Should make a request to the oauth endpoint")

            expect(components.queryItems).to(haveCount(5), description: "Should have 5 query items")

            let clientID = Bundle.main.infoDictionary?["InoreaderClientID"] as? String

            expect(clientID).toNot(beNil())

            expect(components.queryItems).to(contain(
                URLQueryItem(name: "redirect_uri", value: "https://tethys.younata.com/oauth"),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: "read write"),
                URLQueryItem(name: "client_id", value: clientID)
            ))

            guard let stateItem = (components.queryItems ?? []).first(where: { $0.name == "state" }) else {
                fail("No state query item")
                return
            }

            expect(stateItem.value).toNot(beNil())
        }

        it("sets the expected callback scheme") {
            expect(subject.authenticationSession.callbackURLScheme).to(equal("rnews"))
        }

        describe("when the user finishes the session successfully") {
            describe("and everything is hunky-dory") {
                beforeEach {
                    let receivedURL = subject.authenticationSession.url

                    guard let components = URLComponents(url: receivedURL, resolvingAgainstBaseURL: false) else {
                        return
                    }

                    guard let stateItem = (components.queryItems ?? []).first(where: { $0.name == "state" }) else {
                        return
                    }

                    subject.authenticationSession.completionHandler(
                        url(base: "rnews://oauth",
                            queryItems: ["code": "authentication_code", "state": stateItem.value!]),
                        nil
                    )
                }

                it("announces success in the worst way possible") {
                    expect(subject.presentedViewController).to(beAKindOf(UIAlertController.self))

                    guard let alert = subject.presentedViewController as? UIAlertController else { return }

                    expect(alert.title).to(equal("SUCCESS"))

                    expect(alert.message).to(equal("authentication_code"))
                    expect(alert.actions).to(haveCount(1))

                    expect(alert.actions.first?.title).to(equal("ok"))
                    alert.actions.first?.handler?(alert.actions.first!)

                    expect(navigationController.visibleViewController).to(equal(rootViewController))
                }
            }

            describe("and the csrf doesn't match") {
                beforeEach {
                    subject.authenticationSession.completionHandler(
                        url(base: "rnews://oauth",
                            queryItems: ["code": "authentication_code", "state": "badValue"]),
                        nil
                    )
                }

                it("informs the user of the error") {
                    fail("implement me!")
                }
            }
        }

        describe("when the user fails to login") {
            beforeEach {
                let error = NSError(
                    domain: ASWebAuthenticationSessionErrorDomain,
                    code: ASWebAuthenticationSessionError.Code.canceledLogin.rawValue,
                    userInfo: nil)
                subject.authenticationSession.completionHandler(nil, error)
            }

            it("informs the user that we can't login") {
                fail("implement me!")
            }
        }
    }
}

func url(base: String, queryItems: [String: String]) -> URL {
    var components = URLComponents(string: base)!
    components.queryItems = queryItems.map { key, value in
        return URLQueryItem(name: key, value: value)
    }
    return components.url!
}

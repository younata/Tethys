import Quick
import UIKit
import Nimble
import Result
import CBGPromise
@testable import TethysKit

@testable import Tethys

final class OAuthLoginControllerSpec: QuickSpec {
    override func spec() {
        var subject: OAuthLoginController!
        var accountService: FakeAccountService!
        var mainQueue: FakeOperationQueue!

        var authenticationSessions: [ASWebAuthenticationSession] = []

        beforeEach {
            authenticationSessions = []

            accountService = FakeAccountService()

            mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            subject = OAuthLoginController(accountService: accountService, mainQueue: mainQueue, clientId: "testClientId") {
                let session = ASWebAuthenticationSession(url: $0, callbackURLScheme: $1, completionHandler: $2)
                authenticationSessions.append(session)
                return session
            }
        }

        it("does not yet create any authentication sessions") {
            expect(authenticationSessions).to(beEmpty())
        }

        describe("-begin()") {
            var future: Future<Result<Account, TethysError>>!
            var window: UIWindow!

            beforeEach {
                window = UIWindow()
                subject.window = window
                future = subject.begin()
            }

            it("creates an authentication session") {
                expect(authenticationSessions).to(haveCount(1))
            }

            it("starts the created authentication session") {
                expect(authenticationSessions.last?.began).to(beTrue())
            }

            it("sets the session's presentationContextProvider") {
                expect(authenticationSessions.last?.presentationContextProvider).toNot(beNil())
                let provider = authenticationSessions.last?.presentationContextProvider

                expect(provider?.presentationAnchor(for: authenticationSessions.last!)).to(be(window))
            }

            it("configures the authentication session for inoreader with a custom redirect") {
                guard let receivedURL = authenticationSessions.last?.url else { return }

                guard let components = URLComponents(url: receivedURL, resolvingAgainstBaseURL: false) else {
                    fail("Unable to construct URLComponents from \(receivedURL)")
                    return
                }

                expect(components.scheme).to(equal("https"), description: "Should make a request to an https url")
                expect(components.host).to(equal("www.inoreader.com"), description: "Should make a request to inoreader")
                expect(components.path).to(equal("/oauth2/auth"), description: "Should make a request to the oauth endpoint")

                expect(components.queryItems).to(haveCount(5), description: "Should have 5 query items")

                expect(components.queryItems).to(contain(
                    URLQueryItem(name: "redirect_uri", value: "https://tethys.younata.com/oauth"),
                    URLQueryItem(name: "response_type", value: "code"),
                    URLQueryItem(name: "scope", value: "read write"),
                    URLQueryItem(name: "client_id", value: "testClientId")
                ))

                guard let stateItem = (components.queryItems ?? []).first(where: { $0.name == "state" }) else {
                    fail("No state query item")
                    return
                }

                expect(stateItem.value).toNot(beNil())
            }

            it("sets the expected callback scheme") {
                expect(authenticationSessions.last?.callbackURLScheme).to(equal("rnews"))
            }

            describe("when the user finishes the session successfully") {
                describe("and everything is hunky-dory") {
                    beforeEach {
                        guard let receivedURL = authenticationSessions.last?.url else { return }

                        guard let components = URLComponents(url: receivedURL, resolvingAgainstBaseURL: false) else {
                            return
                        }

                        guard let stateItem = (components.queryItems ?? []).first(where: { $0.name == "state" }) else {
                            return
                        }

                        authenticationSessions.last?.completionHandler(
                            url(base: "rnews://oauth",
                                queryItems: ["code": "authentication_code", "state": stateItem.value!]),
                            nil
                        )
                    }

                    it("tells the account service to update it's credentials with the authentication code") {
                        expect(accountService.authenticateCalls).to(equal(["authentication_code"]))
                    }

                    describe("and the account service succeeds") {
                        beforeEach {
                            accountService.authenticatePromises.last?.resolve(.success(Account(
                                kind: .inoreader,
                                username: "a username",
                                id: "an id"
                            )))
                        }

                        it("resolves the future with the account") {
                            expect(future).to(beResolved())
                            expect(future.value?.value).to(equal(Account(
                                kind: .inoreader,
                                username: "a username",
                                id: "an id"
                            )))
                        }
                    }

                    describe("and the account service fails") {
                        beforeEach {
                            accountService.authenticatePromises.last?.resolve(.failure(.unknown))
                        }

                        it("resolves the future with the error") {
                            expect(future).to(beResolved())
                            expect(future.value?.error).to(equal(.unknown))
                        }
                    }
                }

                describe("and the csrf doesn't match") {
                    let csrfURL = url(base: "rnews://oauth",
                    queryItems: ["code": "authentication_code", "state": "badValue"])
                    beforeEach {
                        authenticationSessions.last?.completionHandler(
                            csrfURL,
                            nil
                        )
                    }

                    it("resolves the future with an invalidResponse error") {
                        expect(future).to(beResolved())
                        guard let error = future.value?.error else { fail("error not set"); return }
                        switch error {
                        case .network(let url, let networkError):
                            let body = (csrfURL.query ?? "").data(using: .utf8)!
                            expect(networkError).to(equal(.badResponse(body)))
                            expect(url.absoluteString.hasPrefix("https://www.inoreader.com/oauth2/auth")).to(
                                beTruthy(),
                                description: "Expected url to start with https://www.inoreader.com/oauth2/auth"
                            )
                        default:
                            fail("Expected error to be a badResponse network error, got \(error)")
                        }
                    }
                }
            }

            describe("when the user fails to login") {
                beforeEach {
                    let error = NSError(
                        domain: ASWebAuthenticationSessionErrorDomain,
                        code: ASWebAuthenticationSessionError.Code.canceledLogin.rawValue,
                        userInfo: nil)
                    authenticationSessions.last?.completionHandler(nil, error)
                }

                it("resolves the future with a cancelled error") {
                    expect(future).to(beResolved())
                    guard let error = future.value?.error else { fail("error not set"); return }
                    switch error {
                    case .network(let url, let networkError):
                        expect(networkError).to(equal(.cancelled))
                        expect(url.absoluteString.hasPrefix("https://www.inoreader.com/oauth2/auth")).to(
                            beTruthy(),
                            description: "Expected url to start with https://www.inoreader.com/oauth2/auth"
                        )
                    default:
                        fail("Expected error to be a cancelled network error, got \(error)")
                    }
                }
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

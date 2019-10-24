import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP

@testable import TethysKit

final class InoreaderAccountServiceSpec: QuickSpec {
    override func spec() {
        var subject: InoreaderAccountService!
        var credentialService: FakeCredentialService!
        var httpClient: FakeHTTPClient!

        let clientId = "id"
        let clientSecret = "secret"

        var dateCallCount: Int = 0
        let initialDate = Date()

        beforeEach {
            credentialService = FakeCredentialService()
            httpClient = FakeHTTPClient()

            dateCallCount = 0

            subject = InoreaderAccountService(
                clientId: clientId,
                clientSecret: clientSecret,
                credentialService: credentialService,
                httpClient: httpClient,
                dateOracle: {
                    dateCallCount += 1
                    return initialDate
                }
            )
        }

        describe("-accounts()") {
            var future: Future<[Result<Account, TethysError>]>!
            beforeEach {
                future = subject.accounts()
            }

            it("asks the credential service for the list of credentials") {
                expect(credentialService.credentialsPromises).to(haveCount(1))
            }

            describe("when the credential service returns the account ids") {
                let credentials = [
                    Credential(access: "foo", expiration: initialDate, refresh: "bar", accountId: "foo", accountType: .inoreader),
                    Credential(access: "baz", expiration: initialDate, refresh: "qux", accountId: "bar", accountType: .inoreader),
                ]
                beforeEach {
                    credentialService.credentialsPromises.last?.resolve(.success(credentials))
                }

                it("asks inoreader for the account details of each credential") {
                    expect(httpClient.requests).to(haveCount(2))

                    expect(httpClient.requests).to(contain(
                        request(
                            url: "https://www.inoreader.com/reader/api/0/user-info",
                            headers: ["Authorization": "Bearer foo"]),
                        request(
                            url: "https://www.inoreader.com/reader/api/0/user-info",
                            headers: ["Authorization": "Bearer baz"])
                    ))
                }

                describe("when all requests succeed") {
                    let userInfoFoo: [String: Any] = [
                        "userId": "123",
                        "userName": "a_username",
                        "userProfileId": "123",
                        "userEmail": "foo@example.com",
                        "isBloggerUser": true,
                        "signupTimeSec": 1234567890,
                        "isMultiLoginEnabled": false,
                    ]
                    let userInfoBar: [String: Any] = [
                        "userId": "456",
                        "userName": "another_username",
                        "userProfileId": "456",
                        "userEmail": "bar@example.com",
                        "isBloggerUser": true,
                        "signupTimeSec": 1234567890,
                        "isMultiLoginEnabled": false,
                    ]

                    beforeEach {
                        httpClient.requestPromises.first?.resolve(.success(HTTPResponse(
                            body: try! JSONSerialization.data(withJSONObject: userInfoFoo, options: []),
                            status: .ok,
                            mimeType: "Application/JSON",
                            headers: [:]
                        )))

                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: try! JSONSerialization.data(withJSONObject: userInfoBar, options: []),
                            status: .ok,
                            mimeType: "Application/JSON",
                            headers: [:]
                        )))
                    }

                    it("resolves the future with the account details") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value).to(haveCount(2))

                        guard let accounts = future.value?.compactMap({ $0.value }) else { return }
                        expect(accounts).to(haveCount(2), description: "Expected both results to have succeeded")

                        expect(accounts).to(contain(
                            Account(kind: .inoreader, username: "a_username", id: "123"),
                            Account(kind: .inoreader, username: "another_username", id: "456")
                        ))
                    }
                }

                describe("when the requests fail for other reasons") {
                    beforeEach {
                        httpClient.requestPromises.first?.resolve(.failure(.network(.timedOut)))
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: "Bad Credentials".data(using: .utf8)!,
                            status: .unauthorized,
                            mimeType: "Text/Plain",
                            headers: [:]
                        )))
                    }

                    it("resolves the future with the failure details") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value).to(haveCount(2))

                        guard let errors = future.value?.compactMap({ $0.error }) else { return }
                        expect(errors).to(haveCount(2), description: "Expected both results to have failed")

                        expect(errors).to(contain(
                            TethysError.network(
                                URL(string: "https://www.inoreader.com/reader/api/0/user-info")!,
                                .http(.unauthorized)
                            ),
                            TethysError.network(
                                URL(string: "https://www.inoreader.com/reader/api/0/user-info")!,
                                .timedOut
                            )
                        ))
                    }
                }
            }

            describe("when the credential service runs into an error") {
                beforeEach {
                    credentialService.credentialsPromises.last?.resolve(.failure(.unknown))
                }

                it("resolves the future with the failure") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value).to(haveCount(1))
                    expect(future.value?.first?.error).to(equal(.unknown))
                }
            }
        }

        describe("-authenticate(code:)") {
            var future: Future<Result<Account, TethysError>>!

            beforeEach {
                future = subject.authenticate(code: "my auth code")
            }

            it("makes a request to inoreader to trade the authentication code for actual credentials") {
                let bodyContents = [
                    "code=my%20auth%20code",
                    "redirect_uri=https://tethys.younata.com/oauth",
                    "client_id=\(clientId)",
                    "client_secret=\(clientSecret)",
                    "scope=",
                    "grant_type=authorization_code"
                ].joined(separator: "&")

                expect(httpClient.requests).to(equal([
                    request(
                        url: "https://www.inoreader.com/oauth2/token",
                        headers: ["Content-Type": "application/x-www-form-urlencoded"],
                        method: .post(
                            bodyContents.data(using: .utf8)!
                        )
                    )
                ]))
            }

            describe("when the request succeeds") {
                let response: [String: Any] = [
                    "access_token": "access",
                    "token_type": "Bearer",
                    "expires_in": 60 * 60 * 24,
                    "refresh_token": "refresh",
                    "scope": "some scope"
                ]

                beforeEach {
                    httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                        body: try! JSONSerialization.data(withJSONObject: response, options: []),
                        status: .ok,
                        mimeType: "Application/JSON",
                        headers: [:]
                    )))
                }

                it("gets the date for reasons of knowing when to refresh the account details") {
                    expect(dateCallCount) == 1
                }

                it("makes a request to inoreader to get the account information") {
                    expect(httpClient.requests.last).to(equal(
                        request(
                            url: "https://www.inoreader.com/reader/api/0/user-info",
                            headers: ["Authorization": "Bearer access"]
                        )
                    ))
                }

                describe("when that request succeeds") {
                    let userInfo: [String: Any] = [
                        "userId": "123",
                        "userName": "a_username",
                        "userProfileId": "123",
                        "userEmail": "foo@example.com",
                        "isBloggerUser": true,
                        "signupTimeSec": 1234567890,
                        "isMultiLoginEnabled": false,
                    ]

                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: try! JSONSerialization.data(withJSONObject: userInfo, options: []),
                            status: .ok,
                            mimeType: "Application/JSON",
                            headers: [:]
                        )))
                    }

                    it("stores the credentials") {
                        expect(credentialService.storeCredentialCalls).to(equal([
                            Credential(
                                access: "access",
                                expiration: initialDate.addingTimeInterval(TimeInterval(60 * 60 * 24)),
                                refresh: "refresh",
                                accountId: "123",
                                accountType: .inoreader
                            )
                        ]))
                    }

                    describe("when the store credential request succeeds") {
                        beforeEach {
                            credentialService.storeCredentialPromises.last?.resolve(.success(Void()))
                        }

                        it("resolves the future with the created account, giving it an id of 'inoreader'") {
                            expect(future.value).toNot(beNil(), description: "Expected future to be resolved")

                            expect(future.value?.value).to(equal(
                                Account(kind: .inoreader, username: "a_username", id: "123")
                            ))
                        }
                    }

                    describe("when the store credential request fails") {
                        beforeEach {
                            credentialService.storeCredentialPromises.last?.resolve(.failure(.database(.unknown)))
                        }

                        it("resolves the future with the last failure") {
                            expect(future.value).toNot(beNil(), description: "Expected future to be resolved")

                            expect(future.value?.error).to(equal(.database(.unknown)))
                        }
                    }
                }

                describe("when that request fails for credential reasons") {
                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: "Bad Credentials".data(using: .utf8)!,
                            status: .unauthorized,
                            mimeType: "Text/Plain",
                            headers: [:]
                        )))
                    }

                    it("does not store the credentials") {
                        expect(credentialService.storeCredentialCalls).to(beEmpty())
                    }

                    it("resolves the future with an error") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(equal(TethysError.network(
                            URL(string: "https://www.inoreader.com/reader/api/0/user-info")!, .http(.unauthorized))
                        ))
                    }
                }

                describe("when that request fails") {
                    beforeEach {
                        httpClient.requestPromises.last?.resolve(.failure(.network(.timedOut)))
                    }

                    it("does not store the credentials") {
                        expect(credentialService.storeCredentialCalls).to(beEmpty())
                    }

                    it("resolves the future with an error") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.error).to(equal(.network(
                            URL(string: "https://www.inoreader.com/reader/api/0/user-info")!, .timedOut)
                        ))
                    }
                }
            }

            describe("when the request fails") {
                beforeEach {
                    httpClient.requestPromises.last?.resolve(.failure(.network(.timedOut)))
                }

                it("resolves the future with an error") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.error).to(equal(.network(
                        URL(string: "https://www.inoreader.com/oauth2/token")!, .timedOut)
                    ))
                }
            }
        }
    }
}

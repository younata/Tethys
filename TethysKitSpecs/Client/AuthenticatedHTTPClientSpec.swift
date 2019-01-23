import Quick
import Nimble
import Result
import CBGPromise
import FutureHTTP

@testable import TethysKit

final class AuthenticatedHTTPClientSpec: QuickSpec {
    override func spec() {
        var subject: AuthenticatedHTTPClient!

        var client: FakeHTTPClient!
        var credentialService: FakeCredentialService!

        let refreshURL = URL(string: "https://example.com/oauth2/token")!
        let clientID = "my_client_id"
        let clientSecret = "my_client_secret"
        let account = "my_account"

        let currentDate = Date()

        beforeEach {
            client = FakeHTTPClient()
            credentialService = FakeCredentialService()

            subject = AuthenticatedHTTPClient(
                client: client,
                credentialService: credentialService,
                refreshURL: refreshURL,
                clientId: clientID,
                clientSecret: clientSecret,
                accountId: account,
                dateOracle: { return currentDate }
            )
        }

        describe("request(:)") {
            var future: Future<Result<HTTPResponse, HTTPClientError>>!
            let request = URLRequest(url: URL(string: "https://example.com/foo")!)

            func itBehavesLikeMakingTheRequest() {
                describe("when the request succeeds") {
                    beforeEach {
                        client.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: "hello".data(using: .utf8)!,
                            status: .ok,
                            mimeType: "",
                            headers: [:]
                        )))
                    }

                    it("resolves the future with the value") {
                        expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.value).to(equal(HTTPResponse(
                            body: "hello".data(using: .utf8)!,
                            status: .ok,
                            mimeType: "",
                            headers: [:]
                        )))
                    }
                }

                describe("when the request fails") {
                    describe("with an unauthorized error") {
                        beforeEach {
                            client.requestPromises.last?.resolve(.success(HTTPResponse(
                                body: "bad".data(using: .utf8)!,
                                status: .unauthorized,
                                mimeType: "",
                                headers: [:]
                            )))
                        }

                        it("deletes the original credential") {
                            expect(credentialService.deleteCredentialCalls).to(haveCount(1))
                        }

                        describe("when the delete call succeeds") {
                            beforeEach {
                                credentialService.deleteCredentialPromises.last?.resolve(.success(Void()))
                            }

                            it("resolves the future with that result") {
                                expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                                expect(future.value?.value).to(equal(HTTPResponse(
                                    body: "bad".data(using: .utf8)!,
                                    status: .unauthorized,
                                    mimeType: "",
                                    headers: [:]
                                )))
                            }
                        }

                        describe("when the delete call fails") {
                            beforeEach {
                                credentialService.deleteCredentialPromises.last?.resolve(.failure(.database(.unknown)))
                            }

                            it("resolves the future with that result") {
                                expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                                expect(future.value?.value).to(equal(HTTPResponse(
                                    body: "bad".data(using: .utf8)!,
                                    status: .unauthorized,
                                    mimeType: "",
                                    headers: [:]
                                )))
                            }
                        }
                    }
                    describe("with a generic error") {
                        beforeEach {
                            guard client.requestPromises.last?.future.value == nil else { return }
                            client.requestPromises.last?.resolve(.failure(.unknown))
                        }

                        it("forwards the error") {
                            expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                            expect(future.value?.error).to(equal(.unknown))
                        }
                    }
                }
            }

            func itBehavesLikeRefreshingTheCredential(refreshToken: String, originalCredential: Credential) {
                it("does not make the request to the underlying client yet") {
                    expect(client.requests).toNot(contain(request))
                }

                it("makes a different request to the underlying client to refresh the access token") {
                    let expectedRequest = URLRequest(
                        url: refreshURL,
                        headers: ["content-type": "application/x-www-form-urlencoded"],
                        method: .post(formData(contents: [
                            "client_id": clientID,
                            "client_secret": clientSecret,
                            "grant_type": "refresh",
                            "refresh_token": refreshToken
                        ]))
                    )
                    expect(client.requests).to(equal([
                        expectedRequest
                    ]))
                }

                context("if that request is successful") {
                    let responseData = try! JSONSerialization.data(
                        withJSONObject: [
                            "access_token": "new_token",
                            "token_type": "Bearer",
                            "expires_in": 12345,
                            "refresh_token": "new_refresh",
                            "scope": "read"
                        ],
                        options: []
                    )
                    beforeEach {
                        client.requestPromises.last?.resolve(.success(HTTPResponse(
                            body: responseData,
                            status: .ok,
                            mimeType: "Application/json",
                            headers: [:]
                        )))
                    }

                    it("stores the new credential") {
                        expect(credentialService.storeCredentialCalls).to(equal([
                            Credential(
                                access: "new_token",
                                expiration: currentDate.addingTimeInterval(12345),
                                refresh: "new_refresh",
                                accountId: account,
                                accountType: .inoreader
                            )
                        ]))
                    }

                    describe("when the new credential is stored") {
                        beforeEach {
                            credentialService.storeCredentialPromises.last?.resolve(.success(Void()))
                        }

                        it("makes the original request") {
                            expect(client.requests).to(haveCount(2))
                            expect(client.requests.last?.url).to(equal(request.url))
                            expect(client.requests.last?.allHTTPHeaderFields).to(equal(["Authorization": "Bearer new_token"]))
                        }

                        itBehavesLikeMakingTheRequest()
                    }

                    describe("when the credential fails to be stored") {
                        beforeEach {
                            credentialService.storeCredentialPromises.last?.resolve(.failure(.database(.unknown)))
                        }

                        it("makes the original request") {
                            expect(client.requests).to(haveCount(2))
                            expect(client.requests.last?.url).to(equal(request.url))
                            expect(client.requests.last?.allHTTPHeaderFields).to(equal(["Authorization": "Bearer new_token"]))
                        }

                        itBehavesLikeMakingTheRequest()
                    }
                }

                context("if that request fails") {
                    describe("with a 401") {
                        beforeEach {
                            client.requestPromises.last?.resolve(.success(HTTPResponse(
                                body: "bad".data(using: .utf8)!,
                                status: .unauthorized,
                                mimeType: "",
                                headers: [:]
                            )))
                        }

                        it("deletes the original credential") {
                            expect(credentialService.deleteCredentialCalls).to(haveCount(1))
                        }

                        describe("when the credentials are deleted") {
                            beforeEach {
                                credentialService.deleteCredentialPromises.last?.resolve(.success(Void()))
                            }

                            it("does not make the original request") {
                                expect(client.requests).toNot(contain(request))
                            }

                            it("resolves the future with that result") {
                                expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                                expect(future.value?.value).to(equal(HTTPResponse(
                                    body: "bad".data(using: .utf8)!,
                                    status: .unauthorized,
                                    mimeType: "",
                                    headers: [:]
                                )))
                            }
                        }

                        describe("when the credentials fail to be deleted") {
                            beforeEach {
                                credentialService.deleteCredentialPromises.last?.resolve(.failure(.database(.unknown)))
                            }

                            it("does not make the original request") {
                                expect(client.requests).toNot(contain(request))
                            }

                            it("resolves the future with that result") {
                                expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                                expect(future.value?.value).to(equal(HTTPResponse(
                                    body: "bad".data(using: .utf8)!,
                                    status: .unauthorized,
                                    mimeType: "",
                                    headers: [:]
                                )))
                            }
                        }
                    }

                    describe("with a generic error") {
                        beforeEach {
                            client.requestPromises.last?.resolve(.failure(.unknown))
                        }

                        it("does not make the original request") {
                            expect(client.requests).toNot(contain(request))
                        }

                        it("resolves the future with that error") {
                            expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                            expect(future.value?.error).to(equal(.unknown))
                        }
                    }
                }
            }

            beforeEach {
                future = subject.request(request)
            }

            it("asks the credential service for the credentials") {
                expect(credentialService.credentialsPromises).to(haveCount(1))
            }

            context("if no credential matches what we're looking for") {
                beforeEach {
                    credentialService.credentialsPromises.last?.resolve(.success([
                        Credential(access: "whatever", expiration: currentDate.addingTimeInterval(500), refresh: "whatever", accountId: "nope", accountType: .inoreader)
                    ]))
                }

                it("resolves with an unauthorized error") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.value).to(equal(HTTPResponse(
                        body: Data(),
                        status: .unauthorized,
                        mimeType: "text/plain",
                        headers: [:]
                    )))
                }
            }

            context("if the credential hasn't expired") {
                beforeEach {
                    credentialService.credentialsPromises.last?.resolve(.success([
                        Credential(access: "whatever", expiration: currentDate.addingTimeInterval(6), refresh: "refresh", accountId: account, accountType: .inoreader)
                    ]))
                }

                it("forwards the request to the underlying client, adding an authorization header") {
                    expect(client.requests).to(haveCount(1))
                    expect(client.requests.last?.url).to(equal(request.url))
                    expect(client.requests.last?.allHTTPHeaderFields).to(equal(["Authorization": "Bearer whatever"]))
                }

                itBehavesLikeMakingTheRequest()
            }

            context("if the credential is about to expire") {
                let credential = Credential(access: "whatever", expiration: currentDate.addingTimeInterval(4.9), refresh: "refresh_token", accountId: account, accountType: .inoreader)
                beforeEach {
                    credentialService.credentialsPromises.last?.resolve(.success([
                        credential
                    ]))
                }

                itBehavesLikeRefreshingTheCredential(refreshToken: "refresh_token", originalCredential: credential)
            }

            context("if the credential has expired") {
                let credential = Credential(access: "whatever", expiration: currentDate.addingTimeInterval(-5), refresh: "refresh_token", accountId: account, accountType: .inoreader)

                beforeEach {
                    credentialService.credentialsPromises.last?.resolve(.success([
                        credential
                    ]))
                }

                itBehavesLikeRefreshingTheCredential(refreshToken: "refresh_token", originalCredential: credential)
            }
        }
    }
}

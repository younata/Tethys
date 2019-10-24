import Quick
import Nimble
import Result
import XCTest
import CBGPromise
import SwiftKeychainWrapper

@testable import TethysKit

final class KeychainCredentialServiceSpec: QuickSpec {
    override func spec() {
        var subject: KeychainCredentialService!

        let keychain = KeychainWrapper.standard

        beforeEach {
            subject = KeychainCredentialService(
                keychain: keychain
            )
        }

        afterEach {
            KeychainWrapper.wipeKeychain()
        }

        let credential = Credential(
            access: "foo",
            expiration: Date(timeIntervalSinceReferenceDate: 0),
            refresh: "refresh",
            accountId: "account",
            accountType: .inoreader
        )

        let otherCredential = Credential(
            access: "bar",
            expiration: Date(timeIntervalSinceReferenceDate: 2),
            refresh: "baz",
            accountId: "number 2",
            accountType: .inoreader
        )

        describe("credentials()") {
            var future: Future<Result<[Credential], TethysError>>!

            context("and there is data stored") {
                beforeEach {
                    guard let data = try? JSONEncoder().encode([credential, otherCredential]) else {
                        fail("Failed to encode the credentials into json")
                        return
                    }

                    expect(keychain.set(data, forKey: "credentials")).to(beTruthy())

                    future = subject.credentials()
                }

                it("resolves the future with the stored credentials") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.value).to(haveCount(2))
                    expect(future.value?.value).to(contain(credential, otherCredential))
                }
            }

            context("and there isn't data stored") {
                beforeEach {
                    future = subject.credentials()
                }

                it("resolves with no data") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.value).to(beEmpty())
                }
            }
        }

        describe("store(credential:)") {
            var future: Future<Result<Void, TethysError>>!

            context("and there isn't a credential stored for this account type and id") {
                beforeEach {
                    let data = try! JSONEncoder().encode([otherCredential])
                    expect(keychain.set(data, forKey: "credentials")).to(beTruthy())
                    future = subject.store(credential: credential)
                }

                it("stores the credential in the credentials list") {
                    guard let data = keychain.data(forKey: "credentials") else {
                        fail("no data in keychain")
                        return
                    }
                    guard let credentials = try? JSONDecoder().decode([Credential].self, from: data) else {
                        fail("no credentials stored")
                        return
                    }

                    expect(credentials).to(haveCount(2))

                    expect(credentials).to(contain(credential, otherCredential))
                }

                it("resolves the future with a success") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.value).to(beVoid())
                }
            }

            context("and there is a credential stored for this account type and id") {
                let updatedCredential = Credential(
                    access: "updated_access",
                    expiration: Date(timeIntervalSinceReferenceDate: 10),
                    refresh: "updated_refresh",
                    accountId: credential.accountId,
                    accountType: credential.accountType
                )
                beforeEach {
                    let data = try! JSONEncoder().encode([credential, otherCredential])
                    expect(keychain.set(data, forKey: "credentials")).to(beTruthy())

                    future = subject.store(credential: updatedCredential)
                }

                it("updates the stored credential in the credentials list") {
                    guard let data = keychain.data(forKey: "credentials") else {
                        fail("no data in keychain")
                        return
                    }
                    guard let credentials = try? JSONDecoder().decode([Credential].self, from: data) else {
                        fail("no credentials stored")
                        return
                    }

                    expect(credentials).to(haveCount(2))

                    expect(credentials).to(contain(updatedCredential, otherCredential))
                }

                it("resolves the future with a success") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.value).to(beVoid())
                }
            }
        }

        describe("delete(credential:)") {
            var future: Future<Result<Void, TethysError>>!

            context("and the credential exists") {
                beforeEach {
                    let data = try! JSONEncoder().encode([credential, otherCredential])
                    expect(keychain.set(data, forKey: "credentials")).to(beTruthy())

                    future = subject.delete(credential: credential)
                }

                it("removes the credential from the datastore") {
                    guard let data = keychain.data(forKey: "credentials") else {
                        fail("no data in keychain")
                        return
                    }
                    guard let credentials = try? JSONDecoder().decode([Credential].self, from: data) else {
                        fail("no credentials stored")
                        return
                    }

                    expect(credentials).to(equal([otherCredential]))
                }

                it("resolves with a successful value") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.value).to(beVoid())
                }
            }

            context("and the credential doesn't exist") {
                beforeEach {
                    future = subject.delete(credential: credential)
                }

                it("resolves the future with success") {
                    expect(future.value).toNot(beNil(), description: "Expected future to be resolved")
                    expect(future.value?.value).to(beVoid())
                }
            }
        }
    }
}

final class KeychainCredentialServicePerformanceTest: XCTestCase {
    override func tearDown() {
        KeychainWrapper.wipeKeychain()
    }

    func testPerformance() {
        let credential = Credential(
            access: "foo",
            expiration: Date(timeIntervalSinceReferenceDate: 0),
            refresh: "refresh",
            accountId: "account",
            accountType: .inoreader
        )

        let otherCredential = Credential(
            access: "bar",
            expiration: Date(timeIntervalSinceReferenceDate: 2),
            refresh: "baz",
            accountId: "number 2",
            accountType: .inoreader
        )

        guard let data = try? JSONEncoder().encode([credential, otherCredential]) else {
            fail("Failed to encode the credentials into json")
            return
        }

        let keychain = KeychainWrapper.standard

        let subject = KeychainCredentialService(
            keychain: keychain
        )

        expect(keychain.set(data, forKey: "credentials")).to(beTruthy())

        self.measure {
            expect(subject.credentials().wait()).toNot(beNil())
        }
    }
}

import Quick
import Nimble
import Swinject
import FutureHTTP
import SwiftKeychainWrapper
@testable import TethysKit

class KitModuleSpec: QuickSpec {
    override func spec() {
        var subject: Container! = nil

        beforeEach {
            subject = Container()
            TethysKit.configure(container: subject)
        }

        it("binds the main operation queue to kMainQueue") {
            expect(subject.resolve(OperationQueue.self, name: kMainQueue)).to(beIdenticalTo(OperationQueue.main))
        }

        it("binds a single background queue") {
            expect(subject.resolve(OperationQueue.self, name: kBackgroundQueue)).to(beIdenticalTo(subject.resolve(OperationQueue.self, name: kBackgroundQueue)))
        }

        describe("Services") {
            exists(AccountService.self, kindOf: InoreaderAccountService.self)

            exists(Bundle.self)

            exists(CredentialService.self, kindOf: KeychainCredentialService.self)

            exists(UserDefaults.self)

            exists(FileManager.self)

            exists(Reachable.self)

            exists(RealmProvider.self, kindOf: DefaultRealmProvider.self)

            describe("FeedService") {
                var credentialService: KeychainCredentialService!
                let keychain = KeychainWrapper.standard

                beforeEach {
                    credentialService = KeychainCredentialService(
                        keychain: keychain
                    )

                    KeychainWrapper.wipeKeychain()

                    subject.register(CredentialService.self) { _ in return credentialService }
                }

                afterEach {
                    KeychainWrapper.wipeKeychain()
                }

                context("without a saved inoreader account") {
                    it("is a RealmFeedService") {
                        expect(subject.resolve(FeedService.self)).to(beAKindOf(RealmFeedService.self))
                    }
                }

                context("with a saved inoreader account") {
                    beforeEach {
                        let future = credentialService.store(credential: Credential(
                            access: "access",
                            expiration: Date(),
                            refresh: "refresh",
                            accountId: "some user id",
                            accountType: .inoreader
                        ))
                        expect(future.value).toEventuallyNot(beNil(), description: "Expected future to be resolved")
                        expect(future.value?.value).to(beVoid())
                    }

                    it("is an InoreaderFeedService") {
                        let value = subject.resolve(FeedService.self)
                        expect(value).to(beAKindOf(InoreaderFeedService.self))
                        if let feedService = value as? InoreaderFeedService {
                            expect(feedService.baseURL).to(equal(URL(string: "https://www.inoreader.com")))
                        }
                    }
                }
            }
            exists(FeedService.self, kindOf: RealmFeedService.self)
            exists(FeedCoordinator.self, singleton: true)
            exists(LocalFeedService.self, kindOf: LocalRealmFeedService.self)
            exists(ArticleService.self, kindOf: ArticleRepository.self, singleton: true)

            exists(HTTPClient.self, kindOf: URLSession.self, singleton: true)

            describe("HTTPClient with an account") {
                it("exists") {
                    expect(subject.resolve(HTTPClient.self, argument: "my_account")).toNot(beNil())
                }

                it("is a configured AuthenticatedHTTPClient") {
                    let client = subject.resolve(HTTPClient.self, argument: "my_account")
                    expect(client).to(beAKindOf(AuthenticatedHTTPClient.self))
                    guard let httpClient = client as? AuthenticatedHTTPClient else {
                        fail("Not an AuthenticatedHTTPClient")
                        return
                    }

                    expect(httpClient.client).to(beIdenticalTo(subject.resolve(HTTPClient.self)))
                    expect(httpClient.accountId).to(equal("my_account"))
                    expect(httpClient.refreshURL.absoluteString).to(equal("https://www.inoreader.com/oauth2/token"))
                    expect(httpClient.clientId).to(equal(Bundle.main.infoDictionary?["InoreaderClientID"] as? String))
                    expect(httpClient.clientSecret).to(equal(Bundle.main.infoDictionary?["InoreaderClientSecret"] as? String))
                    expect(httpClient.dateOracle().timeIntervalSince(Date())).to(beCloseTo(0))
                }
            }

            exists(UpdateService.self, kindOf: RealmRSSUpdateService.self)

            singleton(OPMLService.self)
            exists(BackgroundStateMonitor.self)
        }

        func exists<T>(_ type: T.Type, singleton: Bool = false, line: UInt = #line) {
            describe("\(type)") {
                it("exists") {
                    expect(subject.resolve(type), line: line).toNot(beNil())
                }
            }

            if singleton {
                it("is a singleton") {
                    expect(subject.resolve(type), line: line).to(beIdenticalTo(subject.resolve(type)))
                }
            }
        }

        func singleton<T>(_ type: T.Type, line: UInt = #line) {
            describe("\(type)") {
                it("exists") {
                    expect(subject.resolve(type), line: line).toNot(beNil())
                }

                it("is a singleton") {
                    expect(subject.resolve(type), line: line).to(beIdenticalTo(subject.resolve(type)))
                }
            }
        }

        func exists<T, U>(_ type: T.Type, kindOf otherType: U.Type, singleton: Bool = false, line: UInt = #line) {
            describe("\(type)") {
                it("exists") {
                    expect(subject.resolve(type), line: line).toNot(beNil())
                }

                it("is a \(otherType)") {
                    expect(subject.resolve(type), line: line).to(beAKindOf(otherType))
                }

                if singleton {
                    it("is a singleton") {
                        expect(subject.resolve(type), line: line).to(beIdenticalTo(subject.resolve(type)))
                    }
                }
            }
        }

        func alwaysIs<T: Equatable>(_ type: T.Type, a obj: T, line: UInt = #line) {
            describe("\(type)") {
                it("exists") {
                    expect(subject.resolve(type), line: line).toNot(beNil())
                }

                it("is always \(Mirror(reflecting: obj).description)") {
                    expect(subject.resolve(type), line: line).to(equal(obj))
                }
            }
        }
    }
}

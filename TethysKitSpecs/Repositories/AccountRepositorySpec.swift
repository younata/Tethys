import Quick
import Nimble
import CBGPromise
import Result
import Sinope
@testable import TethysKit

class AccountRepositorySpec: QuickSpec {
    override func spec() {
        var subject: DefaultAccountRepository!
        var userDefaults: FakeUserDefaults!
        var repository: FakeSinopeRepository!
        var delegate: FakeAccountRepositoryDelegate!

        beforeEach {
            userDefaults = FakeUserDefaults()
            repository = FakeSinopeRepository()
            delegate = FakeAccountRepositoryDelegate()
            subject = DefaultAccountRepository(repository: repository, userDefaults: userDefaults)

            subject.delegate = delegate
        }

        it("is logged out if user defaults has no login token") {
            expect(subject.loggedIn()).to(beNil())
        }

        describe("if the user token has been saved to user defaults") {
            beforeEach {
                userDefaults.set("oogabooga", forKey: "pasiphae_token")
                userDefaults.set("myTestUser", forKey: "pasiphae_login")
                subject = DefaultAccountRepository(repository: repository, userDefaults: userDefaults)
            }

            it("reports the user as logged in") {
                expect(subject.loggedIn()) == "myTestUser"
            }

            it("logs in to the SinopeRepository") {
                expect(repository.loginAuthTokenCallCount) == 1
                guard repository.loginAuthTokenCallCount > 0 else { return }
                expect(repository.loginAuthTokenArgsForCall(0)) == "oogabooga"
            }
        }

        describe("logging in") {
            var loginFuture: Future<Result<Void, TethysError>>!
            var loginRepositoryPromise: Promise<Result<Void, SinopeError>>!

            beforeEach {
                loginRepositoryPromise = Promise<Result<Void, SinopeError>>()
                repository.loginReturns(loginRepositoryPromise.future)
                loginFuture = subject.login("foo@example.com", password: "password")
            }

            it("returns an in-progress promise") {
                expect(loginFuture.value).to(beNil())
            }

            it("makes a call to the SinopeRepository to login") {
                expect(repository.loginCallCount) == 1
                guard repository.loginCallCount > 0 else { return }
                let args = repository.loginArgsForCall(0)
                expect(args.0) == "foo@example.com"
                expect(args.1) == "password"
            }

            describe("when the call succeeds") {
                beforeEach {
                    repository._authToken = "oogabooga"

                    loginRepositoryPromise.resolve(.success())
                }

                it("successfully resolves the future") {
                    expect(loginFuture.value).toNot(beNil())
                    expect(loginFuture.value?.error).to(beNil())
                    expect(loginFuture.value?.value).toNot(beNil())
                }

                it("saves the result to the user defaults") {
                    expect(userDefaults.string(forKey: "pasiphae_token")) == "oogabooga"
                }

                it("reports the user as logged in") {
                    expect(subject.loggedIn()) == "foo@example.com"
                }

                it("informs the delegate that we logged in") {
                    expect(delegate.accountRepositoryDidLogInCallCount) == 1
                }
            }

            describe("when the call fails") {
                beforeEach {
                    loginRepositoryPromise.resolve(.failure(.network))
                }

                it("resolves the future with an error") {
                    expect(loginFuture.value).toNot(beNil())
                    expect(loginFuture.value?.error) == .backend(.network)
                }
            }
        }

        describe("registering") {
            var registerFuture: Future<Result<Void, TethysError>>!
            var registerRepositoryPromise: Promise<Result<Void, SinopeError>>!

            beforeEach {
                registerRepositoryPromise = Promise<Result<Void, SinopeError>>()
                repository.createAccountReturns(registerRepositoryPromise.future)
                registerFuture = subject.register("foo@example.com", password: "password")
            }

            it("returns an in-progress promise") {
                expect(registerFuture.value).to(beNil())
            }

            it("makes a call to the SinopeRepository to login") {
                expect(repository.createAccountCallCount) == 1
                guard repository.createAccountCallCount > 0 else { return }
                let args = repository.createAccountArgsForCall(0)
                expect(args.0) == "foo@example.com"
                expect(args.1) == "password"
            }

            describe("when the call succeeds") {
                beforeEach {
                    repository._authToken = "oogabooga"

                    registerRepositoryPromise.resolve(.success())
                }

                it("successfully resolves the future") {
                    expect(registerFuture.value).toNot(beNil())
                    expect(registerFuture.value?.error).to(beNil())
                    expect(registerFuture.value?.value).toNot(beNil())
                }

                it("saves the result to the user defaults") {
                    expect(userDefaults.string(forKey: "pasiphae_token")) == "oogabooga"
                }

                it("reports the user as logged in") {
                    expect(subject.loggedIn()) == "foo@example.com"
                }

                it("informs the delegate that we logged in") {
                    expect(delegate.accountRepositoryDidLogInCallCount) == 1
                }
            }

            describe("when the call fails") {
                beforeEach {
                    registerRepositoryPromise.resolve(.failure(.network))
                }

                it("resolves the future with an error") {
                    expect(registerFuture.value).toNot(beNil())
                    expect(registerFuture.value?.error) == .backend(.network)
                }
            }
        }

        describe("getting a repository") {
            it("returns nil if the user is not logged in") {
                expect(subject.backendRepository()).to(beNil())
            }

            it("returns a repository if the user has logged in") {
                userDefaults.set("oogabooga", forKey: "pasiphae_token")
                userDefaults.set("myTestUser", forKey: "pasiphae_login")
                subject = DefaultAccountRepository(repository: repository, userDefaults: userDefaults)

                expect(subject.backendRepository() as? FakeSinopeRepository) == repository
            }
        }

        describe("logging out") {
            it("unsets the pasiphae token and login info") {
                userDefaults.set("oogabooga", forKey: "pasiphae_token")
                userDefaults.set("myTestUser", forKey: "pasiphae_login")

                subject = DefaultAccountRepository(repository: repository, userDefaults: userDefaults)
                subject.logOut()

                expect(userDefaults.string(forKey: "pasiphae_token")).to(beNil())
                expect(userDefaults.string(forKey: "pasiphae_login")).to(beNil())
            }
        }
    }
}

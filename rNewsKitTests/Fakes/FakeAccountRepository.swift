@testable import rNewsKit
import Sinope
import Result
import CBGPromise

// this file was generated by Xcode-Better-Refactor-Tools
// https://github.com/tjarratt/xcode-better-refactor-tools

class FakeAccountRepository : AccountRepository, InternalAccountRepository, Equatable {
    init() {
    }

    private(set) var loginCallCount : Int = 0
    var loginStub : ((String, String) -> (Future<Result<Void, RNewsError>>))?
    private var loginArgs : Array<(String, String)> = []
    func loginReturns(_ stubbedValues: (Future<Result<Void, RNewsError>>)) {
        self.loginStub = {(email: String, password: String) -> (Future<Result<Void, RNewsError>>) in
            return stubbedValues
        }
    }
    func loginArgsForCall(_ callIndex: Int) -> (String, String) {
        return self.loginArgs[callIndex]
    }
    func login(_ email: String, password: String) -> (Future<Result<Void, RNewsError>>) {
        self.loginCallCount += 1
        self.loginArgs.append((email, password))
        return self.loginStub!(email, password)
    }

    private(set) var registerCallCount : Int = 0
    var registerStub : ((String, String) -> (Future<Result<Void, RNewsError>>))?
    private var registerArgs : Array<(String, String)> = []
    func registerReturns(_ stubbedValues: (Future<Result<Void, RNewsError>>)) {
        self.registerStub = {(email: String, password: String) -> (Future<Result<Void, RNewsError>>) in
            return stubbedValues
        }
    }
    func registerArgsForCall(_ callIndex: Int) -> (String, String) {
        return self.registerArgs[callIndex]
    }
    func register(_ email: String, password: String) -> (Future<Result<Void, RNewsError>>) {
        self.registerCallCount += 1
        self.registerArgs.append((email, password))
        return self.registerStub!(email, password)
    }

    private(set) var loggedInCallCount : Int = 0
    var loggedInStub : (() -> (String?))?
    func loggedInReturns(_ stubbedValues: (String?)) {
        self.loggedInStub = {() -> (String?) in
            return stubbedValues
        }
    }
    func loggedIn() -> (String?) {
        self.loggedInCallCount += 1
        return self.loggedInStub!()
    }

    private(set) var logOutCallCount : Int = 0
    func logOut() {
        self.logOutCallCount += 1
    }

    var delegate: AccountRepositoryDelegate?

    private(set) var backendRepositoryCallCount : Int = 0
    var backendRepositoryStub : (() -> Sinope.Repository?)?
    func backendRepositoryReturns(_ stubbedValues: (Sinope.Repository?)) {
        self.backendRepositoryStub = {() -> (Sinope.Repository?) in
            return stubbedValues
        }
    }
    func backendRepository() -> (Sinope.Repository?) {
        self.backendRepositoryCallCount += 1
        return self.backendRepositoryStub!()
    }
}

func == (a: FakeAccountRepository, b: FakeAccountRepository) -> Bool {
    return a === b
}

class FakeAccountRepositoryDelegate : AccountRepositoryDelegate, Equatable {
    init() {
    }

    private(set) var accountRepositoryDidLogInCallCount : Int = 0
    private var accountRepositoryDidLogInArgs : Array<(InternalAccountRepository)> = []
    func accountRepositoryDidLogInArgsForCall(_ callIndex: Int) -> (InternalAccountRepository) {
        return self.accountRepositoryDidLogInArgs[callIndex]
    }
    func accountRepositoryDidLogIn(_ accountRepository: InternalAccountRepository) {
        self.accountRepositoryDidLogInCallCount += 1
        self.accountRepositoryDidLogInArgs.append((accountRepository))
    }

    static func reset() {
    }
}

func == (a: FakeAccountRepositoryDelegate, b: FakeAccountRepositoryDelegate) -> Bool {
    return a === b
}

import Quick
import Nimble
import rNewsKit

class rNewsErrorSpec: QuickSpec {
    override func spec() {
        describe("NetworkError") {
            describe("equality") {
                it("reports two InternetDown errors as equal") {
                    expect(NetworkError.internetDown) == NetworkError.internetDown
                }

                it("reports two DNS errors as equal") {
                    expect(NetworkError.dns) == NetworkError.dns
                }

                it("reports two ServerNotFound errors as equal") {
                    expect(NetworkError.serverNotFound) == NetworkError.serverNotFound
                }

                it("reports two HTTPErrors of the same kind as equal") {
                    let a = NetworkError.http(.badRequest)
                    let b = NetworkError.http(.badRequest)
                    let c = NetworkError.http(.internalServerError)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Unknown errors as equal") {
                    expect(NetworkError.unknown) == NetworkError.unknown
                }
            }
        }

        describe("RNewsError") {
            describe("equality") {
                it("reports two Network errors of the same kind as equal") {
                    let a = RNewsError.network(URL(string: "https://example.com")!, .internetDown)
                    let b = RNewsError.network(URL(string: "https://example.com")!, .internetDown)
                    let c = RNewsError.network(URL(string: "https://example.org")!, .internetDown)
                    let d = RNewsError.network(URL(string: "https://example.com")!, .dns)

                    expect(a) == b
                    expect(a) != c
                    expect(a) != d
                }

                it("reports two HTTP errors of the same kind as equal") {
                    let a = RNewsError.http(404)
                    let b = RNewsError.http(404)
                    let c = RNewsError.http(500)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Database errors of the same kind as equal") {
                    let a = RNewsError.database(.notFound)
                    let b = RNewsError.database(.notFound)
                    let c = RNewsError.database(.unknown)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Backend errors of the same kind as equal") {
                    let a = RNewsError.backend(.unknown)
                    let b = RNewsError.backend(.unknown)
                    let c = RNewsError.backend(.network)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Book errors of the same kind as equal") {
                    let a = RNewsError.book(.unknown)
                    let b = RNewsError.book(.unknown)
                    let c = RNewsError.book(.invalidRequest("hello"))

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Unknown errors as equal") {
                    let a = RNewsError.unknown
                    let b = RNewsError.unknown

                    expect(a) == b
                }

                it("reports two disperate errors as unequal") {
                    let a = RNewsError.network(URL(string: "https://example.com")!, .unknown)
                    let b = RNewsError.http(0)
                    let c = RNewsError.database(.unknown)
                    let d = RNewsError.unknown

                    expect(a) != b
                    expect(a) != c
                    expect(a) != d

                    expect(b) != c
                    expect(b) != d

                    expect(c) != d
                }
            }
        }
    }
}

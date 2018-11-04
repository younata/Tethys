import Quick
import Nimble
import TethysKit

class TethysErrorSpec: QuickSpec {
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

        describe("TethysError") {
            describe("equality") {
                it("reports two Network errors of the same kind as equal") {
                    let a = TethysError.network(URL(string: "https://example.com")!, .internetDown)
                    let b = TethysError.network(URL(string: "https://example.com")!, .internetDown)
                    let c = TethysError.network(URL(string: "https://example.org")!, .internetDown)
                    let d = TethysError.network(URL(string: "https://example.com")!, .dns)

                    expect(a) == b
                    expect(a) != c
                    expect(a) != d
                }

                it("reports two HTTP errors of the same kind as equal") {
                    let a = TethysError.http(404)
                    let b = TethysError.http(404)
                    let c = TethysError.http(500)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Database errors of the same kind as equal") {
                    let a = TethysError.database(.notFound)
                    let b = TethysError.database(.notFound)
                    let c = TethysError.database(.unknown)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Book errors of the same kind as equal") {
                    let a = TethysError.book(.unknown)
                    let b = TethysError.book(.unknown)
                    let c = TethysError.book(.invalidRequest("hello"))

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Unknown errors as equal") {
                    let a = TethysError.unknown
                    let b = TethysError.unknown

                    expect(a) == b
                }

                it("reports two disperate errors as unequal") {
                    let a = TethysError.network(URL(string: "https://example.com")!, .unknown)
                    let b = TethysError.http(0)
                    let c = TethysError.database(.unknown)
                    let d = TethysError.unknown

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

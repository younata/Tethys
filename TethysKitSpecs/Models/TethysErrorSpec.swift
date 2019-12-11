import Quick
import Nimble
import TethysKit

class TethysErrorSpec: QuickSpec {
    override func spec() {
        describe("NetworkError") {
            describe("equality") {
                it("reports two InternetDown errors as equal") {
                    expect(NetworkError.internetDown).to(equal(NetworkError.internetDown))
                }

                it("reports two DNS errors as equal") {
                    expect(NetworkError.dns).to(equal(NetworkError.dns))
                }

                it("reports two ServerNotFound errors as equal") {
                    expect(NetworkError.serverNotFound).to(equal(NetworkError.serverNotFound))
                }

                it("reports two HTTPErrors of the same kind as equal") {
                    let a = NetworkError.http(.badRequest, Data())
                    let b = NetworkError.http(.badRequest, Data())
                    let c = NetworkError.http(.internalServerError, Data())

                    expect(a).to(equal(b))
                    expect(a).toNot(equal(c))
                }

                it("reports two Unknown errors as equal") {
                    expect(NetworkError.unknown).to(equal(NetworkError.unknown))
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

                    expect(a).to(equal(b))
                    expect(a).toNot(equal(c))
                    expect(a).toNot(equal(d))
                }

                it("reports two HTTP errors of the same kind as equal") {
                    let a = TethysError.http(404)
                    let b = TethysError.http(404)
                    let c = TethysError.http(500)

                    expect(a).to(equal(b))
                    expect(a).toNot(equal(c))
                }

                it("reports two Database errors of the same kind as equal") {
                    let a = TethysError.database(.notFound)
                    let b = TethysError.database(.notFound)
                    let c = TethysError.database(.unknown)

                    expect(a).to(equal(b))
                    expect(a).toNot(equal(c))
                }

                it("reports two Unknown errors as equal") {
                    let a = TethysError.unknown
                    let b = TethysError.unknown

                    expect(a).to(equal(b))
                }

                it("reports two disperate errors as unequal") {
                    let a = TethysError.network(URL(string: "https://example.com")!, .unknown)
                    let b = TethysError.http(0)
                    let c = TethysError.database(.unknown)
                    let d = TethysError.unknown

                    expect(a).toNot(equal(b))
                    expect(a).toNot(equal(c))
                    expect(a).toNot(equal(d))

                    expect(b).toNot(equal(c))
                    expect(b).toNot(equal(d))

                    expect(c).toNot(equal(d))
                }
            }

            describe("localizedDescription") {
                it("network") {
                    let error = TethysError.network(
                        URL(string: "https://example.com/foo")!,
                        NetworkError.dns
                    )

                    expect(error.localizedDescription).to(equal("Unable to load https://example.com/foo - DNS Error"))
                }

                it("http") {
                    let error = TethysError.http(404)
                    expect(error.localizedDescription).to(equal("Error loading resource, received 404"))
                }

                it("database") {
                    let error = TethysError.database(.entryNotFound)
                    expect(error.localizedDescription).to(equal("Entry not found"))
                }

                it("notSupported") {
                    let error = TethysError.notSupported
                    expect(error.localizedDescription).to(equal("Not supported by backend"))
                }

                it("unknown") {
                    let error = TethysError.unknown
                    expect(error.localizedDescription).to(equal("Unknown Error - please try again"))
                }
            }
        }
    }
}

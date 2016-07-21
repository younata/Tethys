import Quick
import Nimble
import rNewsKit

class rNewsErrorSpec: QuickSpec {
    override func spec() {
        describe("NetworkError") {
            describe("equality") {
                it("reports two InternetDown errors as equal") {
                    expect(NetworkError.InternetDown) == NetworkError.InternetDown
                }

                it("reports two DNS errors as equal") {
                    expect(NetworkError.DNS) == NetworkError.DNS
                }

                it("reports two ServerNotFound errors as equal") {
                    expect(NetworkError.ServerNotFound) == NetworkError.ServerNotFound
                }

                it("reports two HTTPErrors of the same kind as equal") {
                    let a = NetworkError.HTTP(.BadRequest)
                    let b = NetworkError.HTTP(.BadRequest)
                    let c = NetworkError.HTTP(.InternalServerError)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Unknown errors as equal") {
                    expect(NetworkError.Unknown) == NetworkError.Unknown
                }
            }
        }

        describe("RNewsError") {
            describe("equality") {
                it("reports two Network errors of the same kind as equal") {
                    let a = RNewsError.Network(NSURL(string: "https://example.com")!, .InternetDown)
                    let b = RNewsError.Network(NSURL(string: "https://example.com")!, .InternetDown)
                    let c = RNewsError.Network(NSURL(string: "https://example.org")!, .InternetDown)
                    let d = RNewsError.Network(NSURL(string: "https://example.com")!, .DNS)

                    expect(a) == b
                    expect(a) != c
                    expect(a) != d
                }

                it("reports two HTTP errors of the same kind as equal") {
                    let a = RNewsError.HTTP(404)
                    let b = RNewsError.HTTP(404)
                    let c = RNewsError.HTTP(500)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Database errors of the same kind as equal") {
                    let a = RNewsError.Database(.NotFound)
                    let b = RNewsError.Database(.NotFound)
                    let c = RNewsError.Database(.Unknown)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Backend errors of the same kind as equal") {
                    let a = RNewsError.Backend(.Unknown)
                    let b = RNewsError.Backend(.Unknown)
                    let c = RNewsError.Backend(.Network)

                    expect(a) == b
                    expect(a) != c
                }

                it("reports two Unknown errors as equal") {
                    let a = RNewsError.Unknown
                    let b = RNewsError.Unknown

                    expect(a) == b
                }

                it("reports two disperate errors as unequal") {
                    let a = RNewsError.Network(NSURL(string: "")!, .Unknown)
                    let b = RNewsError.HTTP(0)
                    let c = RNewsError.Database(.Unknown)
                    let d = RNewsError.Unknown

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

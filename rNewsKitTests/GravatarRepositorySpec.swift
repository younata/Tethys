import Quick
import Nimble
import Result
import CBGPromise
@testable import rNewsKit

class GravatarRepositorySpec: QuickSpec {
    override func spec() {
        var subject: DefaultGravatarRepository!
        var urlSession: FakeURLSession!

        beforeEach {
            urlSession = FakeURLSession()
            subject = DefaultGravatarRepository(urlSession: urlSession)
        }

        describe("grabbing a user's gravatar") {
            var future: Future<Result<Image, GravatarRepositoryError>>!
            beforeEach {
                future = subject.image("RACHEL@example.com")
            }

            it("returns an in-progress future") {
                expect(future.value).to(beNil())
            }

            it("makes a request for the image") {
                expect(urlSession.lastURL) == NSURL(string: "http://www.gravatar.com/avatar/0add223192e767646a3cb35693814621")
            }

            context("when the request succeeds") {
                let url = NSBundle(forClass: self.classForCoder).URLForResource("AppIcon", withExtension: "png")!
                let data = NSData(contentsOfURL: url)!
                beforeEach {
                    urlSession.lastCompletionHandler(data, nil, nil)
                }

                it("resolves the promise with the decoded image") {
                    expect(future.value?.value).toNot(beNil())
                }

                describe("making another request for that same image") {
                    var otherFuture: Future<Result<Image, GravatarRepositoryError>>!
                    beforeEach {
                        urlSession.lastURL = nil
                        otherFuture = subject.image("rachel@example.com")
                    }

                    it("returns a resolved promise with the decoded image") {
                        expect(otherFuture.value?.value) === future.value?.value
                    }

                    it("does not make another request") {
                        expect(urlSession.lastURL).to(beNil())
                    }
                }
            }

            context("when the request fails") {
                beforeEach {
                    urlSession.lastCompletionHandler(nil, nil, NSError(domain: "", code: 0, userInfo: nil))
                }

                it("resolves the promise with an error of NetworkError") {
                    expect(future.value?.error) == .Network
                }
            }
        }
    }
}

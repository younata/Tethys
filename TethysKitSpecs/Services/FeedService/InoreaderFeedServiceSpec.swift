import Quick
import Nimble
import Result
import CBGPromise

@testable import TethysKit

final class InoreaderFeedServiceSpec: QuickSpec {
    override func spec() {
        var subject: InoreaderFeedService!

        beforeEach {
            subject = InoreaderFeedService()
        }

        describe("feeds()") {
            var future: Future<Result<AnyCollection<Feed>, TethysError>>!

            beforeEach {
                future = subject.feeds()
            }

            it("asks inoreader for the list of feeds") {
                fail("do it")
            }
        }
    }
}

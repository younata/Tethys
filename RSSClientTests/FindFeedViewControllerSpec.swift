import Quick
import Nimble
import Ra

class FindFeedViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FindFeedViewController! = nil

        let application = UIApplication.sharedApplication()
        var injector : Ra.Injector! = nil

        beforeEach {
            injector = Ra.Injector()
            subject = injector.create(FindFeedViewController.self) as FindFeedViewController
            let feedManager = FeedManagerMock()
            injector.bind(FeedManager.self, to: feedManager)
        }

        describe("Looking up feeds on the interwebs") {
            it("should auto-prepend 'https://' if it's not already there") {
                subject.navField.text = "example.com"
                subject.textFieldShouldReturn(subject.navField)
                expect(subject.navField.text).to(equal("https://example.com"))
            }
        }
    }
}

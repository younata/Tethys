import Quick
import Nimble

import rNewsKit

class WebPageParserSpec: QuickSpec {
    override func spec() {
        var subject: WebPageParser!

        let bundle = NSBundle(forClass: self.classForCoder)
        let url = bundle.URLForResource("webpage", withExtension: "html")!
        let webPage = try! String(contentsOfURL: url, encoding: NSUTF8StringEncoding)

        var receivedUrls: [NSURL]? = nil

        beforeEach {
            receivedUrls = nil
            subject = WebPageParser(string: webPage) {
                receivedUrls = $0
            }
        }

        it("returns the found feeds when it completes") {
            subject.start()

            expect(receivedUrls) == [NSURL(string: "/feed.xml")!, NSURL(string: "/feed2.xml")!]
        }
    }
}

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

        describe("specifying a search for feeds") {
            it("returns the found feeds when it completes") {
                subject.searchType = .Feeds
                subject.start()

                expect(receivedUrls) == [NSURL(string: "/feed.xml")!, NSURL(string: "/feed2.xml")!]
            }
        }

        describe("Specifying links") {
            it("returns all links of type <a href=...") {
                subject.searchType = .Links
                subject.start()

                let urls = [
                    "/",
                    "#",
                    "/about/",
                    "/libraries/",
                    "/2015/12/23/iot-homemade-thermostat/",
                    "/2015/08/21/osx-programming-set-up-core-animation/",
                    "/2015/08/14/osx-programming-programmatic-menu-buttons/",
                    "/2015/08/08/osx-programming-programmatic-scrolling-tableview/",
                    "/2015/07/21/muon-rss-parsing-swift/",
                    "/2015/01/28/setting-up-travis-for-objc/",
                    "/2014/07/31/homekit-basics/",
                    "/feed.xml",
                    "https://github.com/younata",
                    "https://twitter.com/younata"
                ].flatMap(NSURL.init)

                expect(receivedUrls) == urls
            }
        }
    }
}

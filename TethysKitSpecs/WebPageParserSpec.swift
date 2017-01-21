import Quick
import Nimble

import TethysKit

class WebPageParserSpec: QuickSpec {
    override func spec() {
        var subject: WebPageParser!

        let bundle = Bundle(for: self.classForCoder)
        let url = bundle.url(forResource: "webpage", withExtension: "html")!
        let webPage = try! String(contentsOf: url)

        var receivedUrls: [URL]? = nil

        beforeEach {
            receivedUrls = nil
            subject = WebPageParser(string: webPage) {
                receivedUrls = $0
            }
        }

        describe("specifying a search for feeds") {
            it("returns the found feeds when it completes") {
                subject.searchType = .feeds
                subject.start()

                expect(receivedUrls) == [URL(string: "/feed.xml")!, URL(string: "/feed2.xml")!]
            }
        }

        describe("Specifying links") {
            it("returns all links of type <a href=...") {
                subject.searchType = .links
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
                ].flatMap(URL.init)

                expect(receivedUrls) == urls
            }
        }
    }
}

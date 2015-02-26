import Quick
import Nimble
import XCTest

class FeedParserSpec: QuickSpec {
    override func spec() {
        let bundle = NSBundle(forClass: OPMLParserSpec.self)
        let str = String(contentsOfFile: bundle.pathForResource("test", ofType: "opml")!, encoding: NSUTF8StringEncoding, error: nil)!

        describe("performance tests") {
            it("is reasonably performant") {
//                self.measureBlock() {
//                    for i in 0..<1000 {
//                        let fp = FeedParser(string: str)
//                        fp.parse()
//                    }
//                }
            }
        }
    }
}

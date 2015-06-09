import Quick
import Nimble
import rNews

class OPMLParserSpec: QuickSpec {
    override func spec() {
        let bundle = NSBundle(forClass: OPMLParserSpec.self)
        let str = try! String(contentsOfFile: bundle.pathForResource("test", ofType: "opml")!, encoding: NSUTF8StringEncoding)
        
        
        describe("Parsing a string") {
            let parser = OPMLParser(text: str)
            
            it("pulls out regular feeds") {
                parser.success {(items) in
                    let regularFeeds = items.filter { !$0.isQueryFeed() }
                    expect(regularFeeds.count).to(equal(2))
                    if let feed = regularFeeds.first {
                        expect(feed.title).to(equal("nil"))
                        expect(feed.summary).to(beNil())
                        expect(feed.xmlURL).to(equal("http://example.com/feedWithTag"))
                        expect(feed.query).to(beNil())
                        expect(feed.tags).to(equal(["a tag"]))
                    }
                    if let feed = regularFeeds.last {
                        expect(feed.title).to(equal("Feed With Title"))
                        expect(feed.summary).to(beNil())
                        expect(feed.xmlURL).to(equal("http://example.com/feedWithTitle"))
                        expect(feed.query).to(beNil())
                        expect(feed.tags).to(beNil())
                    }
                }
                parser.main()
            }
            
            it("pulls out query feeds") {
                parser.success {(items) in
                    let queryFeeds = items.filter { $0.isQueryFeed() }
                    expect(queryFeeds.count).to(equal(1))
                    if let feed = queryFeeds.first {
                        expect(feed.title).to(equal("Query Feed"))
                        expect(feed.summary).to(beNil())
                        expect(feed.xmlURL).to(beNil())
                        expect(feed.query).to(equal("return true;"))
                        expect(feed.tags).to(beNil())
                    }
                }
                parser.main()
            }
        }
    }
}

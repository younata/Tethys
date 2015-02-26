import Quick
import Nimble

class FeedParserSpec: QuickSpec {
    override func spec() {
        let bundle = NSBundle(forClass: FeedParserSpec.self)
        let str = String(contentsOfFile: bundle.pathForResource("feed", ofType: "rss")!, encoding: NSUTF8StringEncoding, error: nil)!

        var parsers : [FeedParser] = []

        describe("performance tests") {
            it("is reasonably performant") {
                let startTime = CACurrentMediaTime();
                let amount = 20
                println("\n\n\n\n\n")
                for i in 0..<amount {
                    let fp = FeedParser(string: str)
                    fp.asynch = true
                    fp.success {(_, _) in
                        parsers.removeAtIndex(0)
                        if parsers.count == 0 {
                            let time = (CACurrentMediaTime() - startTime) / Double(amount);
                            println("1 run takes about \(time) seconds")
                            println("\n\n\n\n\n")
                        }
                    }
                    fp.failure {(error) in
                        println("\(error)")
                        parsers.removeAtIndex(0)
                        if parsers.count == 0 {
                            let time = (CACurrentMediaTime() - startTime) / Double(amount);
                            println("1 run takes about \(time) seconds")
                            println("\n\n\n\n\n")
                        }
                    }
                    parsers.append(fp)
                    fp.parse()
                }
                expect(parsers.count).toEventually(equal(0), timeout: 60)
            }
        }
    }
}

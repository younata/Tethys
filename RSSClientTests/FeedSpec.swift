import Quick
import Nimble

class FeedSpec: QuickSpec {
    override func spec() {
        var subject : Feed! = nil
        describe("waitPeriodInRefreshes") {
            func feedWithWaitPeriod(waitPeriod: Int) -> Feed {
                return Feed(title: "", url: nil, summary: "", query: nil, tags: [],
                    waitPeriod: waitPeriod, remainingWait: 0, articles: [], image: nil)
            }

            it("should return a number based on the fibonacci sequence offset by 2") {
                subject = feedWithWaitPeriod(0)
                expect(subject.waitPeriodInRefreshes()).to(equal(0))
                subject = feedWithWaitPeriod(1)
                expect(subject.waitPeriodInRefreshes()).to(equal(0))
                subject = feedWithWaitPeriod(2)
                expect(subject.waitPeriodInRefreshes()).to(equal(0))
                subject = feedWithWaitPeriod(3)
                expect(subject.waitPeriodInRefreshes()).to(equal(1))
                subject = feedWithWaitPeriod(4)
                expect(subject.waitPeriodInRefreshes()).to(equal(1))
                subject = feedWithWaitPeriod(5)
                expect(subject.waitPeriodInRefreshes()).to(equal(2))
                subject = feedWithWaitPeriod(6)
                expect(subject.waitPeriodInRefreshes()).to(equal(3))
                subject = feedWithWaitPeriod(7)
                expect(subject.waitPeriodInRefreshes()).to(equal(5))
                subject = feedWithWaitPeriod(8)
                expect(subject.waitPeriodInRefreshes()).to(equal(8))
            }
        }

        it("correctly identifies itself as a query feed or not") {
            let regularFeed = Feed(title: "", url: nil, summary: "", query: nil, tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            let queryFeed = Feed(title: "", url: nil, summary: "", query: "", tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            expect(regularFeed.isQueryFeed).to(beFalsy())
            expect(queryFeed.isQueryFeed).to(beTruthy())
        }

        it("should return the correct number of unread feeds") {

        }

        describe("updates") {
            beforeEach {
                subject = Feed(title: "", url: nil, summary: "", query: nil, tags: [],
                    waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
            }

            it("should change the 'updated' property whenever a property is changed") {

            }
        }
    }
}

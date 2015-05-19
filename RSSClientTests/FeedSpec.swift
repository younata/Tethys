import Quick
import Nimble

class FeedSpec: QuickSpec {
    override func spec() {
        var subject : Feed! = nil

        beforeEach {
            subject = Feed(title: "", url: nil, summary: "", query: nil, tags: [],
                waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        }

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

        it("should return the correct number of unread articles") {

        }

        describe("Equatable") {
            it("should report two feeds created with a coredatafeed with the same feedID as equal") {
                let ctx = managedObjectContext()
                let a = createFeed(ctx)
                let b = createFeed(ctx)

                expect(Feed(feed: a)).toNot(equal(Feed(feed: b)))
                expect(Feed(feed: a)).to(equal(Feed(feed: a)))
            }

            it("should report two feeds not created with coredatafeeds with the same property equality as equal") {
                let a = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
                let b = Feed(title: "blah", url: nil, summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
                let c = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)

                expect(a).toNot(equal(b))
                expect(a).to(equal(c))
            }
        }

        describe("Hashable") {
            it("should report two feeds created with a coredatafeed with the same feedID as having the same hashValue") {
                let ctx = managedObjectContext()
                let a = createFeed(ctx)
                let b = createFeed(ctx)

                expect(Feed(feed: a).hashValue).toNot(equal(Feed(feed: b).hashValue))
                expect(Feed(feed: a).hashValue).to(equal(Feed(feed: a).hashValue))
            }

            it("should report two feeds not created with coredatafeeds with the same property equality as having the same hashValue") {
                let a = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
                let b = Feed(title: "blah", url: nil, summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
                let c = Feed(title: "", url: nil, summary: "", query: nil, tags: [], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)

                expect(a.hashValue).toNot(equal(b.hashValue))
                expect(a.hashValue).to(equal(c.hashValue))
            }
        }

        describe("the updated flag") {
            it("should start negative") {
                expect(subject.updated).to(beFalsy())
            }

            describe("properties that change updated to positive") {
                it("title") {
                    subject.title = ""
                    expect(subject.updated).to(beFalsy())
                    subject.title = "title"
                    expect(subject.updated).to(beTruthy())
                }
            }
        }
    }
}

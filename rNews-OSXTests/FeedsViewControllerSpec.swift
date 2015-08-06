import Quick
import Nimble
import Cocoa
import rNews
import rNewsKit
import Ra

class FeedsViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsViewController! = nil
        var injector: Injector! = nil
        var dataReadWriter: FakeDataReadWriter! = nil

        let feed1 = Feed(title: "feed1", url: nil, summary: "feed1Summary", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        let feed2 = Feed(title: "feed2", url: nil, summary: "feed2Summary", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

        let feeds = [feed1, feed2]

        beforeEach {
            subject = FeedsViewController()

            injector = Injector()

            dataReadWriter = FakeDataReadWriter()
            injector.bind(DataWriter.self, to: dataReadWriter)
            injector.bind(DataRetriever.self, to: dataReadWriter)

            dataReadWriter.feedsList = feeds

            subject.configure(injector)
        }

        it("should ask for the list of feeds") {
            expect(dataReadWriter.didAskForFeeds).to(beTruthy())
        }

        it("should add a subscriber to the dataWriter") {
            expect(dataReadWriter.subscribers.isEmpty).to(beFalsy())
        }

        describe("the tableview") {
            var delegate: NSTableViewDelegate! = nil
            var dataSource: NSTableViewDataSource! = nil
            beforeEach {
                delegate = subject.tableView.delegate()
                dataSource = subject.tableView.dataSource()
            }

            it("should have a row for each feed") {
                expect(dataSource.numberOfRowsInTableView?(subject.tableView)).to(equal(feeds.count))
            }

            describe("a row") {
                var row: FeedView? = nil

                beforeEach {
                    row = delegate.tableView?(subject.tableView, rowViewForRow: 0) as? FeedView
                    expect(row).toNot(beNil())
                }

                it("should be configured for the feed") {
                    expect(row?.feed).to(equal(feeds[0]))
                }
            }
        }

        describe("when the feeds update") {
            let feed3 = Feed(title: "feed3", url: nil, summary: "feed3Summary", query: nil, tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            let updatedFeeds = [feed1, feed2, feed3]

            var dataSource: NSTableViewDataSource! = nil

            beforeEach {
                dataReadWriter.feedsList = updatedFeeds
                for subscriber in dataReadWriter.subscribers {
                    subscriber.updatedFeeds([])
                }

                dataSource = subject.tableView.dataSource()
            }

            it("should update the feeds") {
                expect(dataSource.numberOfRowsInTableView?(subject.tableView)).to(equal(updatedFeeds.count))
            }
        }
    }
}

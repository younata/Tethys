import Quick
import Nimble
import Ra
import rNews
import BreakOutToRefresh

class FeedsTableViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsTableViewController! = nil
        var injector : Injector! = nil
        var dataManager: DataManagerMock! = nil

        var feed1: Feed! = nil
        var feed2: Feed! = nil

        var feeds: [Feed] = []

        beforeEach {
            injector = Injector()
            dataManager = DataManagerMock()
            injector.bind(DataManager.self, to: dataManager)

            subject = injector.create(FeedsTableViewController.self) as! FeedsTableViewController

            feed1 = Feed(title: "a", url: NSURL(string: "http://example.com/feed"), summary: "", query: nil,
                tags: ["a", "b", "c"], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
            feed2 = Feed(title: "d", url: nil, summary: "", query: "", tags: [],
                waitPeriod: nil, remainingWait: nil, articles: [], image: nil)

            feeds = [feed1, feed2]

            dataManager.feedsList = feeds

            expect(subject.view).toNot(beNil())
        }

        describe("pull to refresh") {
            beforeEach {
                expect(dataManager.didUpdateFeeds).to(beFalsy())
                subject.refreshView.beginRefreshing()
                subject.refreshViewDidRefresh(subject.refreshView)
            }

            it("should tell the dataManager to updateFeeds") {
                expect(dataManager.didUpdateFeeds).to(beTruthy())
            }

            it("should be refreshing") {
                expect(subject.refreshView.isRefreshing).to(beTruthy())
            }

            context("when the call succeeds") {
                var feed3: Feed! = nil
                beforeEach {
                    feed3 = Feed(title: "d", url: nil, summary: "", query: "", tags: [],
                        waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
                    dataManager.feedsList = feeds + [feed3]
                    dataManager.updateFeedsCompletion(nil)
                }

                it("should end refreshing") {
                    expect(subject.refreshView.isRefreshing).to(beFalsy())
                }

                it("should reload the tableView") {
                    expect(subject.tableView.numberOfRowsInSection(0)).to(equal(3)) // cause it was 2
                }
            }

            context("when the call fails") {
                var window: UIWindow! = nil
                beforeEach {
                    window = UIWindow()
                    window.makeKeyAndVisible()
                    window.rootViewController = subject
                    let error = NSError(domain: "spec", code: 666, userInfo: [NSLocalizedFailureReasonErrorKey: "Bad Connection"])
                    dataManager.updateFeedsCompletion(error)
                }

                it("should end refreshing") {
                    expect(subject.refreshView.isRefreshing).to(beFalsy())
                }

                it("should bring up an alert notifying the user") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                    if let alert = subject.presentedViewController as? UIAlertController {
                        expect(alert.title).to(equal("Unable to update feeds"))
                        expect(alert.message).to(equal("Bad Connection"))

                        if let actions = alert.actions as? [UIAlertAction] {
                            expect(actions.count).to(equal(1))
                            if let action = actions.first {
                                expect(action.title).to(equal("OK"))
                            }
                        }
                    }
                }
            }
        }

        describe("the tableView") {
            it("should have a row for each feed") {
                expect(subject.tableView.numberOfRowsInSection(0)).to(equal(feeds.count))
            }

            describe("a cell") {
                var cell: FeedTableCell! = nil
                var feed: Feed! = nil

                beforeEach {
                    cell = subject.tableView.visibleCells().first as? FeedTableCell
                    feed = feeds[0]

                    expect(cell).to(beAnInstanceOf(FeedTableCell.self))
                }

                it("should be configured with the feed") {
                    expect(cell.feed).to(equal(feed))
                }

                describe("exposing edit controls") {
                    var actions: [UITableViewRowAction] = []
                    beforeEach {
                        let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                        actions = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath) as? [UITableViewRowAction] ?? []
                    }

                    it("should have an action for deleting the feed") {
                        expect(actions.first?.title).to(equal("Delete"))
                    }

                    it("should have an action for marking all items in the feed as read") {
                        expect(actions[1].title).to(equal("Mark\nRead"))
                    }

                    it("should have an action for editing the feed") {
                        expect(actions.last?.title).to(equal("Edit"))
                    }
                }
            }
        }
    }
}

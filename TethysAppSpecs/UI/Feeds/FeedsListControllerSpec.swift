import Quick
import Nimble
import Tethys
import TethysKit

class FeedsListControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsListController! = nil

        var themeRepository: ThemeRepository! = nil

        var feeds = [Feed]()

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)

            subject = FeedsListController(mainQueue: FakeOperationQueue(), themeRepository: themeRepository)
            feeds = [
                Feed(title: "a", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
                Feed(title: "b", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            ]
            subject.feeds = feeds

            subject.view.layoutIfNeeded()
        }

        describe("listening to theme repository updates") {
            beforeEach {
                expect(subject.view).toNot(beNil())

                themeRepository.theme = .dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the scroll indicator style") {
                expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
            }
        }

        describe("as a FeedsSource") {
            describe("deleteFeed") {
                it("returns a completed future") {
                    expect(subject.deleteFeed(feed: feeds[0]).value) == false
                }
            }

            describe("markRead") {
                it("returns a completed future") {
                    expect(subject.markRead(feed: feeds[0]).value).toNot(beNil())
                }
            }

            describe("selectFeed") {
                it("calls the callback with the feed") {
                    var tappedFeed: Feed? = nil
                    subject.tapFeed = { feed in
                        tappedFeed = feed
                    }
                    subject.selectFeed(feed: feeds[0])
                    expect(tappedFeed) == feeds[0]
                }
            }
        }

        it("should have feeds.count number of rows") {
            expect(subject.tableView.dataSource?.tableView(subject.tableView, numberOfRowsInSection: 0)).to(equal(feeds.count))
        }

        describe("a cell") {
            var cell: FeedTableCell? = nil

            let indexPath = IndexPath(row: 0, section: 0)

            beforeEach {
                cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: indexPath) as? FeedTableCell

                expect(cell).toNot(beNil())
            }

            it("should be configured with a feed") {
                expect(cell?.feed).to(equal(feeds[indexPath.row]))
            }

            it("should be configured with the theme repository") {
                expect(cell?.themeRepository).to(beIdenticalTo(themeRepository))
            }

            it("should call the callback when tapped") {
                var tappedFeed: Feed? = nil
                subject.tapFeed = { feed in
                    tappedFeed = feed
                }
                subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAt: indexPath)

                expect(tappedFeed).to(equal(feeds[indexPath.row]))
            }
        }
    }
}

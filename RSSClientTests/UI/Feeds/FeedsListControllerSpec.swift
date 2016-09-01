import Quick
import Nimble
import rNews
import rNewsKit
import Ra

class FeedsListControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsListController! = nil

        var themeRepository: ThemeRepository! = nil

        var feeds = [Feed]()

        beforeEach {
            subject = FeedsListController()
            feeds = [
                Feed(title: "a", url: NSURL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
                Feed(title: "b", url: NSURL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
            ]
            subject.feeds = feeds

            themeRepository = ThemeRepository(userDefaults: nil)
            subject.themeRepository = themeRepository

            subject.view.layoutIfNeeded()
        }

        describe("listening to theme repository updates") {
            beforeEach {
                expect(subject.view).toNot(beNil())

                themeRepository.theme = .Dark
            }

            it("should update the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the scroll indicator style") {
                expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
            }
        }

        it("should have feeds.count number of rows") {
            expect(subject.tableView.dataSource?.tableView(subject.tableView, numberOfRowsInSection: 0)).to(equal(feeds.count))
        }

        describe("a cell") {
            var cell: FeedTableCell? = nil

            let indexPath = NSIndexPath(forRow: 0, inSection: 0)

            beforeEach {
                cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as? FeedTableCell

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
                var tappedRow: Int? = nil
                subject.tapFeed = { feed, row in
                    tappedFeed = feed
                    tappedRow = row
                }
                subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)

                expect(tappedFeed).to(equal(feeds[indexPath.row]))
                expect(tappedRow).to(equal(indexPath.row))
            }

            it("should ask the callback for edit actions") {
                var feedAskedFor: Feed? = nil
                let rowAction = UITableViewRowAction(style: .Default, title: "hi", handler: { _ in })
                subject.editActionsForFeed = {feed in
                    feedAskedFor = feed
                    return [rowAction]
                }

                let rowActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)
                expect(rowActions).to(equal([rowAction]))
                expect(feedAskedFor).to(equal(feeds[indexPath.row]))
            }
        }
    }
}

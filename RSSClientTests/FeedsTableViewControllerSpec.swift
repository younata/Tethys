import Quick
import Nimble
import Ra
import rNews
import BreakOutToRefresh
import Robot

class FeedsTableViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsTableViewController! = nil
        var injector : Injector! = nil
        var dataManager: DataManagerMock! = nil
        var navigationController: UINavigationController! = nil
        var window: UIWindow! = nil

        var feed1: Feed! = nil
        var feed2: Feed! = nil

        var feeds: [Feed] = []

        beforeEach {
            injector = Injector()
            dataManager = DataManagerMock()
            injector.bind(kBackgroundQueue, to: FakeOperationQueue())
            injector.bind(DataManager.self, to: dataManager)

            subject = injector.create(FeedsTableViewController.self) as! FeedsTableViewController

            navigationController = UINavigationController(rootViewController: subject)

            window = UIWindow()
            window.makeKeyAndVisible()
            window.rootViewController = navigationController

            feed1 = Feed(title: "a", url: NSURL(string: "http://example.com/feed"), summary: "", query: nil,
                tags: ["a", "b", "c"], waitPeriod: nil, remainingWait: nil, articles: [], image: nil)
            feed2 = Feed(title: "d", url: nil, summary: "", query: "", tags: [],
                waitPeriod: nil, remainingWait: nil, articles: [], image: nil)

            feeds = [feed1, feed2]

            dataManager.feedsList = feeds

            expect(subject.view).toNot(beNil())
        }

        describe("typing in the searchbar") {
            beforeEach {
                subject.searchBar.delegate?.searchBar?(subject.searchBar, textDidChange: "a")
            }

            it("should filter feeds down to only those with tags that match the search string") {
                expect(subject.tableView.numberOfRowsInSection(0)).to(equal(1))

                if let cell = subject.tableView.visibleCells()[0] as? FeedTableCell {
                    expect(cell.feed).to(equal(feeds[0]))
                }
            }
        }

        describe("tapping the add feed button") {
            var addButton: UIBarButtonItem! = nil
            var buttons: [UIButton] = []
            beforeEach {
                addButton = subject.navigationItem.rightBarButtonItems?.first as? UIBarButtonItem
                addButton.tap()
                buttons = subject.dropDownMenu.valueForKey("_buttons") as? [UIButton] ?? []
                expect(buttons.count).toNot(equal(0))
            }

            afterEach {
                // seriously?
                navigationController.popToRootViewControllerAnimated(false)
                subject.dropDownMenu.closeAnimated(false)
            }

            it("should bring up the dropDownMenu") {
                expect(subject.dropDownMenu.isOpen).to(beTruthy())
                let expectedTitles = ["Add from Web", "Add from Local", "Create Query Feed"]
                let titles: [String] = buttons.map { $0.titleForState(.Normal) ?? "" }
                expect(titles).to(equal(expectedTitles))
            }

            context("tapping on the add feed button again") {
                beforeEach {
                    addButton.tap()
                }

                it("should close the dropDownMenu") {
                    expect(subject.dropDownMenu.isOpen).to(beFalsy())
                }
            }

            context("tapping on add from web") {
                beforeEach {
                    let button = buttons[0]
                    button.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                }

                it("should close the dropDownMenu") {
                    expect(subject.dropDownMenu.isOpen).to(beFalsy())
                }

                it("should present a FindFeedViewController") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                    if let nc = subject.presentedViewController as? UINavigationController {
                        expect(nc.topViewController).to(beAnInstanceOf(FindFeedViewController.self))
                    }
                }
            }

            context("tapping on add from local") {
                beforeEach {
                    let button = buttons[1]
                    button.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                }

                it("should close the dropDownMenu") {
                    expect(subject.dropDownMenu.isOpen).to(beFalsy())
                }

                it("should present a LocalImportViewController") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                    if let nc = subject.presentedViewController as? UINavigationController {
                        expect(nc.topViewController).to(beAnInstanceOf(LocalImportViewController.self))
                    }
                }
            }

            context("tapping on create query feed") {
                beforeEach {
                    let button = buttons[2]
                    button.sendActionsForControlEvents(UIControlEvents.TouchUpInside)
                }

                it("should close the dropDownMenu") {
                    expect(subject.dropDownMenu.isOpen).to(beFalsy())
                }

                it("should present a QueryFeedViewController") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                    if let nc = subject.presentedViewController as? UINavigationController {
                        expect(nc.topViewController).to(beAnInstanceOf(QueryFeedViewController.self))
                    }
                }
            }
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
                var alert: UIAlertController? = nil
                beforeEach {
                    let error = NSError(domain: "spec", code: 666, userInfo: [NSLocalizedFailureReasonErrorKey: "Bad Connection"])
                    dataManager.updateFeedsCompletion(error)
                    alert = subject.presentedViewController as? UIAlertController
                }

                it("should end refreshing") {
                    expect(subject.refreshView.isRefreshing).to(beFalsy())
                }

                it("should bring up an alert notifying the user") {
                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                    if let alert = alert {
                        expect(alert.title).to(equal("Unable to update feeds"))
                        expect(alert.message).to(equal("Bad Connection"))
                    }
                }

                it("should dismiss the alert when tapping the single (OK) button") {
                    if let actions = alert?.actions as? [UIAlertAction] {
                        expect(actions.count).to(equal(1))
                        if let action = actions.first {
                            expect(action.title).to(equal("OK"))
                            action.handler()(action)
                            expect(subject.presentedViewController).to(beNil())
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

                describe("tapping on a cell") {
                    beforeEach {
                        let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                        subject.tableView(subject.tableView, didSelectRowAtIndexPath: indexPath)
                        RBTimeLapse.advanceMainRunLoop()
                    }

                    it("should navigate to an ArticleListViewController for that feed") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                        if let articleList = navigationController.topViewController as? ArticleListController {
                            expect(articleList.feeds).to(equal([feed]))
                        }
                    }
                }

                describe("exposing edit actions") {
                    var actions: [UITableViewRowAction] = []
                    var action: UITableViewRowAction! = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                    beforeEach {
                        actions = subject.tableView(subject.tableView, editActionsForRowAtIndexPath: indexPath) as? [UITableViewRowAction] ?? []
                    }

                    it("should have 3 actions") {
                        expect(actions.count).to(equal(3))
                    }

                    describe("the first action") {
                        beforeEach {
                            action = actions[0]
                        }

                        it("should state it deletes the feed") {
                            expect(action.title).to(equal("Delete"))
                        }

                        describe("tapping it") {
                            beforeEach {
                                action.handler()(action, indexPath)
                            }

                            it("should delete the feed from the data store") {
                                expect(dataManager.lastDeletedFeed).to(equal(feed))
                            }
                        }
                    }

                    describe("the second action") {
                        beforeEach {
                            action = actions[1]
                        }

                        it("should state it marks all items in the feed as read") {
                            expect(action.title).to(equal("Mark\nRead"))
                        }

                        describe("tapping it") {
                            beforeEach {
                                action.handler()(action, indexPath)
                            }

                            it("should mark all articles of that feed as read") {
                                expect(dataManager.lastFeedMarkedRead).to(equal(feed))
                            }
                        }
                    }

                    describe("the second action") {
                        beforeEach {
                            action = actions[2]
                        }

                        it("should state it edits the feed") {
                            expect(action.title).to(equal("Edit"))
                        }

                        describe("tapping it") {
                            beforeEach {
                                action.handler()(action, indexPath)
                                RBTimeLapse.advanceMainRunLoop()
                            }

                            it("should bring up a feed edit screen") {
                                expect(navigationController.topViewController).to(beAnInstanceOf(FeedViewController.self))
                            }
                        }
                    }
                }
            }
        }
    }
}

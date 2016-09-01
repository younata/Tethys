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

        let feed1 = Feed(title: "feed1", url: NSURL(string: "https://example.com")!, summary: "feed1Summary", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        let feed2 = Feed(title: "feed2", url: NSURL(string: "https://example.com")!, summary: "feed2Summary", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

        let feeds = [feed1, feed2]

        var mainMenu: NSMenu? = nil

        beforeEach {
            subject = FeedsViewController()

            injector = Injector()

            dataReadWriter = FakeDataReadWriter()
            injector.bind(DataWriter.self, to: dataReadWriter)
            injector.bind(DataRetriever.self, to: dataReadWriter)

            mainMenu = NSMenu(title: "")
            mainMenu?.addItemWithTitle("a", action: "", keyEquivalent: "")
            mainMenu?.addItemWithTitle("b", action: "", keyEquivalent: "")
            mainMenu?.addItemWithTitle("c", action: "", keyEquivalent: "")
            injector.bind(kMainMenu, to: mainMenu!)

            dataReadWriter.feedsList = feeds

            subject.configure(injector)
        }

        it("should ask for the list of feeds") {
            expect(dataReadWriter.didAskForFeeds) == true
        }

        it("should add a subscriber to the dataWriter") {
            expect(dataReadWriter.subscribers.allObjects.isEmpty) == false
        }

        describe("the main menu") {
            var feedsMenuItem: NSMenuItem? = nil
            beforeEach {
                feedsMenuItem = mainMenu?.itemWithTitle("Feeds")
            }

            it("should add 'feeds' menu item to the main menu") {
                expect(feedsMenuItem).toNot(beNil())
                expect(feedsMenuItem?.target as? NSObject).toNot(beNil())
                if let target = feedsMenuItem?.target as? NSObject,
                   let action = feedsMenuItem?.action {
                    expect(target.respondsToSelector(action)) == true
                }
            }

            it("should add a submenu to the 'feeds' menu item") {
                expect(feedsMenuItem?.submenu).toNot(beNil())
            }

            describe("the 'feeds' section") {
                var feedsSubMenu: NSMenu? = nil
                beforeEach {
                    feedsSubMenu = feedsMenuItem?.submenu
                }

                it("has an option for deleting all feeds") {
                    let deleteAllItem = feedsSubMenu?.itemWithTitle("Delete all feeds")
                    expect(deleteAllItem).toNot(beNil())
                    guard let deleteItem = deleteAllItem else {
                        return
                    }

                    expect(deleteItem.keyEquivalent).to(equal("D"))
                    expect(deleteItem.enabled) == true
                    expect(deleteItem.target as? NSObject).toNot(beNil())

                    if let target = deleteItem.target as? NSObject {
                        dataReadWriter.feedsList = []
                        target.performSelector(deleteItem.action)

                        expect(dataReadWriter.deletedFeeds).to(equal(feeds))

                        expect(subject.tableView.dataSource()?.numberOfRowsInTableView?(subject.tableView)).to(equal(0))
                    }
                }

                it("has an option for reloading feeds") {
                    let reloadAllItem = feedsSubMenu?.itemWithTitle("Refresh feeds")
                    expect(reloadAllItem).toNot(beNil())
                    guard let reloadItem = reloadAllItem else {
                        return
                    }

                    expect(reloadItem.keyEquivalent).to(equal("r"))
                    expect(reloadItem.enabled) == true
                    expect(reloadItem.target as? NSObject).toNot(beNil())

                    if let target = reloadItem.target as? NSObject {
                        target.performSelector(reloadItem.action)

                        expect(dataReadWriter.didUpdateFeeds) == true
                    }
                }

                it("has an option for marking all feeds as read") {
                    let markAllReadItem = feedsSubMenu?.itemWithTitle("Mark all feeds as read")
                    expect(markAllReadItem).toNot(beNil())
                    guard let markReadItem = markAllReadItem else {
                        return
                    }

                    expect(markReadItem.keyEquivalent).to(equal("R"))
                    expect(markReadItem.enabled) == true
                    expect(markReadItem.target as? NSObject).toNot(beNil())

                    if let target = markReadItem.target as? NSObject {
                        dataReadWriter.feedsList = [] // tests that it reloads data
                        target.performSelector(markReadItem.action)

                        expect(dataReadWriter.markedReadFeeds).to(equal(feeds))

                        expect(subject.tableView.dataSource()?.numberOfRowsInTableView?(subject.tableView)).to(equal(0))
                    }
                }
            }
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
                    row = delegate.tableView?(subject.tableView, viewForTableColumn: nil, row: 0) as? FeedView
                    expect(row).toNot(beNil())
                }

                it("should be configured for the feed") {
                    expect(row?.feed).to(equal(feed1))
                }

                describe("the row's delegate") {
                    var delegate: FeedViewDelegate? = nil

                    beforeEach {
                        delegate = row?.delegate
                        expect(delegate).toNot(beNil())
                    }

                    it("should forward a click event to the MainController") {
                        var clickedFeed: Feed? = nil
                        subject.onFeedSelection = {feed in
                            clickedFeed = feed
                        }
                        delegate?.didClickFeed(feed1)
                        expect(clickedFeed).to(equal(feed1))
                    }

                    describe("for a secondary click") {
                        it("should return menu options") {
                            let menuOptions = ["Mark as Read", "Delete"]
                            expect(delegate?.menuOptionsForFeed(feed1)).to(equal(menuOptions))
                        }

                        describe("selecting 'Mark as Read' as the menu option") {
                            beforeEach {
                                delegate?.didSelectMenuOption("Mark as Read", forFeed: feed1)
                            }

                            it("should mark the contents of the feed as read") {
                                expect(dataReadWriter.lastFeedMarkedRead).to(equal(feed1))
                            }
                        }

                        describe("selecting 'Delete' as the menu option") {
                            let updatedFeeds = [feed2]
                            beforeEach {
                                dataReadWriter.feedsList = updatedFeeds
                                delegate?.didSelectMenuOption("Delete", forFeed: feed1)
                            }

                            it("should delete the feed when the 'delete' option is selected") {
                                expect(dataReadWriter.lastDeletedFeed).to(equal(feed1))
                            }

                            it("should update the feeds") {
                                expect(dataSource.numberOfRowsInTableView?(subject.tableView)).to(equal(updatedFeeds.count))
                            }
                        }
                    }
                }
            }
        }

        describe("when the feeds update") {
            let feed3 = Feed(title: "feed3", url: NSURL(string: "https://example.com")!, summary: "feed3Summary", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

            let updatedFeeds = [feed1, feed2, feed3]

            var dataSource: NSTableViewDataSource! = nil

            beforeEach {
                dataReadWriter.feedsList = updatedFeeds
                for object in dataReadWriter.subscribers.allObjects {
                    if let subscriber = object as? DataSubscriber {
                        subscriber.didUpdateFeeds([])
                    }
                }

                dataSource = subject.tableView.dataSource()
            }

            it("should update the feeds") {
                expect(dataSource.numberOfRowsInTableView?(subject.tableView)).to(equal(updatedFeeds.count))
            }
        }
    }
}

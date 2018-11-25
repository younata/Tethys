import Quick
import Nimble
import Cocoa
import Tethys
import TethysKit

class FeedsViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedsViewController! = nil
        var injector: Injector! = nil
        var databaseUseCase: FakeDatabaseUseCase! = nil

        let feed1 = Feed(title: "feed1", url: URL(string: "https://example.com")!, summary: "feed1Summary", tags: [], articles: [], image: nil)
        let feed2 = Feed(title: "feed2", url: URL(string: "https://example.com")!, summary: "feed2Summary", tags: [], articles: [], image: nil)

        let feeds = [feed1, feed2]

        var mainMenu: NSMenu? = nil

        beforeEach {
            subject = FeedsViewController()

            injector = Injector()

            databaseUseCase = FakeDatabaseUseCase()
            injector.bind(kind: DatabaseUseCase.self, toInstance: databaseUseCase)

            mainMenu = NSMenu(title: "")
            mainMenu?.addItem(withTitle: "a", action: #selector(BlankTarget.blank), keyEquivalent: "")
            mainMenu?.addItem(withTitle: "b", action: #selector(BlankTarget.blank), keyEquivalent: "")
            mainMenu?.addItem(withTitle: "c", action: #selector(BlankTarget.blank), keyEquivalent: "")
            injector.bind(string: kMainMenu, toInstance: mainMenu!)

            subject.configure(injector)

            databaseUseCase.feedsPromises.last?.resolve(.success(feeds))
        }

        it("should ask for the list of feeds") {
            expect(databaseUseCase.feedsPromises.count) == 1
        }

        it("should add a subscriber to the dataWriter") {
            expect(databaseUseCase.subscribers.allObjects.isEmpty) == false
        }

        describe("the main menu") {
            var feedsMenuItem: NSMenuItem? = nil
            beforeEach {
                feedsMenuItem = mainMenu?.item(withTitle: "Feeds")
            }

            it("should add 'feeds' menu item to the main menu") {
                expect(feedsMenuItem).toNot(beNil())
                expect(feedsMenuItem?.target as? NSObject).toNot(beNil())
                if let target = feedsMenuItem?.target as? NSObject,
                   let action = feedsMenuItem?.action {
                    expect(target.responds(to: action)) == true
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
                    let deleteAllItem = feedsSubMenu?.item(withTitle: "Delete all feeds")
                    expect(deleteAllItem).toNot(beNil())
                    guard let deleteItem = deleteAllItem else {
                        return
                    }

                    expect(deleteItem.keyEquivalent).to(equal("D"))
                    expect(deleteItem.isEnabled) == true
                    expect(deleteItem.target as? NSObject).toNot(beNil())

                    if let target = deleteItem.target as? NSObject {
                        target.perform(deleteItem.action)

                        expect(databaseUseCase.deletedFeeds).to(equal(feeds))

                        databaseUseCase.feedsPromises.last?.resolve(.success([]))

                        expect(subject.tableView.dataSource?.numberOfRows?(in: subject.tableView)).to(equal(0))
                    }
                }

                it("has an option for reloading feeds") {
                    let reloadAllItem = feedsSubMenu?.item(withTitle: "Refresh feeds")
                    expect(reloadAllItem).toNot(beNil())
                    guard let reloadItem = reloadAllItem else {
                        return
                    }

                    expect(reloadItem.keyEquivalent).to(equal("r"))
                    expect(reloadItem.isEnabled) == true
                    expect(reloadItem.target as? NSObject).toNot(beNil())

                    if let target = reloadItem.target as? NSObject {
                        target.perform(reloadItem.action)

                        expect(databaseUseCase.didUpdateFeeds) == true
                    }
                }

                it("has an option for marking all feeds as read") {
                    let markAllReadItem = feedsSubMenu?.item(withTitle: "Mark all feeds as read")
                    expect(markAllReadItem).toNot(beNil())
                    guard let markReadItem = markAllReadItem else {
                        return
                    }

                    expect(markReadItem.keyEquivalent).to(equal("R"))
                    expect(markReadItem.isEnabled) == true
                    expect(markReadItem.target as? NSObject).toNot(beNil())

                    if let target = markReadItem.target as? NSObject {
                        target.perform(markReadItem.action)

                        expect(databaseUseCase.markedReadFeeds).to(equal(feeds))

                        databaseUseCase.feedsPromises.last?.resolve(.success([]))

                        expect(subject.tableView.dataSource?.numberOfRows?(in: subject.tableView)).to(equal(0))
                    }
                }
            }
        }

        describe("the tableview") {
            var delegate: NSTableViewDelegate! = nil
            var dataSource: NSTableViewDataSource! = nil
            beforeEach {
                delegate = subject.tableView.delegate
                dataSource = subject.tableView.dataSource
            }

            it("should have a row for each feed") {
                expect(dataSource.numberOfRows?(in: subject.tableView)).to(equal(feeds.count))
            }

            describe("a row") {
                var row: FeedView? = nil

                beforeEach {
                    row = delegate.tableView?(subject.tableView, viewFor: nil, row: 0) as? FeedView
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
                                expect(databaseUseCase.lastFeedMarkedRead).to(equal(feed1))
                            }
                        }

                        describe("selecting 'Delete' as the menu option") {
                            let updatedFeeds = [feed2]
                            beforeEach {
                                delegate?.didSelectMenuOption("Delete", forFeed: feed1)
                                databaseUseCase.feedsPromises.last?.resolve(.success(updatedFeeds))
                            }

                            it("should delete the feed when the 'delete' option is selected") {
                                expect(databaseUseCase.lastDeletedFeed).to(equal(feed1))
                            }

                            it("should update the feeds") {
                                expect(dataSource.numberOfRows?(in: subject.tableView)).to(equal(updatedFeeds.count))
                            }
                        }
                    }
                }
            }
        }

        describe("when the feeds update") {
            let feed3 = Feed(title: "feed3", url: URL(string: "https://example.com")!, summary: "feed3Summary", tags: [], articles: [], image: nil)

            let updatedFeeds = [feed1, feed2, feed3]

            var dataSource: NSTableViewDataSource! = nil

            beforeEach {
                for object in databaseUseCase.subscribers.allObjects {
                    if let subscriber = object as? DataSubscriber {
                        subscriber.didUpdateFeeds([])
                    }
                }

                databaseUseCase.feedsPromises.last?.resolve(.success(updatedFeeds))

                dataSource = subject.tableView.dataSource
            }

            it("should update the feeds") {
                expect(dataSource.numberOfRows?(in: subject.tableView)).to(equal(updatedFeeds.count))
            }
        }
    }
}

import Quick
import Nimble
import Ra
import Muon
import rNews

private func createOPMLWithFeeds(feeds: [(url: String, title: String)], location: String) {
    var opml = "<opml><body>"
    for feed in feeds {
        opml += "<outline xmlURL=\"\(feed.url)\" title=\"\(feed.title)\" type=\"rss\"/>"
    }
    opml += "</body></opml>"

    let path = documentsDirectory().stringByAppendingPathComponent(location)
    do {
        try opml.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
    } catch _ {
    }
}

private func deleteAtLocation(location: String) {
    let path = documentsDirectory().stringByAppendingPathComponent(location)
    do {
        try NSFileManager.defaultManager().removeItemAtPath(path)
    } catch _ {
    }
}

private func createFeed(feed: (url: String, title: String, articles: [String]), location: String) {
    var str = "<rss><channel><title>\(feed.title)</title><link>\(feed.url)</link>"
    for article in feed.articles {
        str += "<item><title>\(article)</title></item>"
    }
    str += "</channel></rss>"

    let path = documentsDirectory().stringByAppendingPathComponent(location)
    do {
        try str.writeToFile(path, atomically: true, encoding: NSUTF8StringEncoding)
    } catch _ {
    }
}

class LocalImportViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: LocalImportViewController! = nil
        var injector: Ra.Injector! = nil

        var navigationController : UINavigationController! = nil

        var tableView : UITableView! = nil

        var dataManager: DataManagerMock! = nil
        var opmlManager: OPMLManagerMock! = nil
        var backgroundQueue : FakeOperationQueue! = nil

        beforeEach {
            injector = Ra.Injector(module: SpecInjectorModule())
            dataManager = DataManagerMock()
            injector.bind(DataManager.self, to: dataManager)
            opmlManager = OPMLManagerMock()
            injector.bind(OPMLManager.self, to: opmlManager)
            backgroundQueue = injector.create(kBackgroundQueue) as! FakeOperationQueue
            backgroundQueue.runSynchronously = true
            subject = injector.create(LocalImportViewController.self) as! LocalImportViewController

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
            tableView = subject.tableViewController.tableView
        }

        it("should have 2 sections") {
            expect(subject.numberOfSectionsInTableView(tableView)).to(equal(2))
        }

        it("should start out with 0 rows in each section") {
            expect(subject.tableView(tableView, numberOfRowsInSection: 0)).to(equal(1)) // feeds.opml & rnews.opml
            expect(subject.tableView(tableView, numberOfRowsInSection: 1)).to(equal(0))
        }

        it("should list OPML first, then RSS feeds") {
            let opmlHeader = subject.tableView(tableView, titleForHeaderInSection: 0)
            let feedHeader = subject.tableView(tableView, titleForHeaderInSection: 1)
            expect(opmlHeader!).to(equal("Feed Lists"))
            expect(feedHeader!).to(equal("Individual Feeds"))
        }

        describe("reloading objects") {
            let opmlFeeds : [(url: String, title: String)] = [("http://example.com/feed1", "feed1"), ("http://example.com/feed2", "feed2")]
            let rssFeed : (url: String, title: String, articles: [String]) = ("http://example.com/feed", "feed", ["article1", "article2"])

            beforeEach {
                createOPMLWithFeeds(opmlFeeds, location: "rnews.opml")
                createFeed(rssFeed, location: "feed")
                subject.reloadItems()
            }

            afterEach {
                deleteAtLocation("opml")
                deleteAtLocation("feed")
            }

            it("should with 1 row in each section") {
                expect(subject.tableView(tableView, numberOfRowsInSection: 0)).to(equal(1))
                expect(subject.tableView(tableView, numberOfRowsInSection: 1)).to(equal(1))
            }

            describe("the cell in section 0") {
                var cell : UITableViewCell? = nil
                let indexPath = NSIndexPath(forRow: 0, inSection: 0)
                beforeEach {
                    expect(subject.numberOfSectionsInTableView(tableView)).to(beGreaterThan(indexPath.section))
                    if subject.numberOfSectionsInTableView(tableView) > indexPath.section {
                        expect(subject.tableView(tableView, numberOfRowsInSection: indexPath.section)).to(beGreaterThan(indexPath.row))
                        if subject.tableView(tableView, numberOfRowsInSection: indexPath.section) > indexPath.row {
                            cell = subject.tableView(tableView, cellForRowAtIndexPath: indexPath)
                        }
                    }
                }

                it("should be named for the file name") {
                    expect(cell?.textLabel?.text).to(equal("rnews.opml"))
                }

                it("should list how many feeds are in this opml file") {
                    expect(cell?.detailTextLabel?.text).to(equal("2 feeds"))
                }

                describe("selecting it") {
                    beforeEach {
                        subject.tableView(tableView, didSelectRowAtIndexPath: indexPath)
                    }

                    it("should present an activity indicator") {
                        var indicator : ActivityIndicator? = nil
                        for view in subject.view.subviews {
                            if view is ActivityIndicator {
                                indicator = view as? ActivityIndicator
                                break
                            }
                        }
                        expect(indicator).toNot(beNil())
                        if let activityIndicator = indicator {
                            expect(activityIndicator.message).to(equal("Importing feeds"))
                        }
                    }

                    it("disable the dismiss button") {
                        expect(subject.navigationItem.leftBarButtonItem?.enabled).to(beFalsy())
                    }

                    it("should disenable user interaction") {
                        expect(subject.view.userInteractionEnabled).to(beFalsy())
                    }

                    it("should import the feeds") {
                        let expectedLocation = documentsDirectory().stringByAppendingPathComponent("rnews.opml")
                        expect(opmlManager.importOPMLURL).to(equal(NSURL(string: "file://" + expectedLocation)))
                    }

                    describe("when it's done importing the feeds") {
                        beforeEach {
                            opmlManager.importOPMLCompletion([])
                        }

                        it("should remove the activity indicator") {
                            var indicator : ActivityIndicator? = nil
                            for view in subject.view.subviews {
                                if view is ActivityIndicator {
                                    indicator = view as? ActivityIndicator
                                    break
                                }
                            }
                            expect(indicator).to(beNil())
                        }

                        it("should re-enable user interaction") {
                            expect(subject.view.userInteractionEnabled).to(beTruthy())
                        }

                        it("should re-enable the dismiss button") {
                            expect(subject.navigationItem.leftBarButtonItem?.enabled).to(beTruthy())
                        }
                    }
                }
            }

            describe("the cell in section 1") {
                var cell : UITableViewCell! = nil
                let indexPath = NSIndexPath(forRow: 0, inSection: 1)
                beforeEach {
                    cell = subject.tableView(tableView, cellForRowAtIndexPath: indexPath)
                }

                it("should be named for the file name") {
                    expect(cell.textLabel?.text).to(equal("feed"))
                }

                it("should list how many articles are in this feed") {
                    expect(cell.detailTextLabel?.text).to(equal("2 articles"))
                }

                describe("selecting it") {
                    beforeEach {
                        subject.tableView(tableView, didSelectRowAtIndexPath: indexPath)
                    }

                    it("should present an activity indicator") {
                        var indicator : ActivityIndicator? = nil
                        for view in subject.view.subviews {
                            if view is ActivityIndicator {
                                indicator = view as? ActivityIndicator
                                break
                            }
                        }
                        expect(indicator).toNot(beNil())
                        if let activityIndicator = indicator {
                            expect(activityIndicator.message).to(equal("Importing feed"))
                        }
                    }

                    it("disable the dismiss button") {
                        expect(subject.navigationItem.leftBarButtonItem?.enabled).to(beFalsy())
                    }

                    it("should disable user interaction") {
                        expect(subject.view.userInteractionEnabled).to(beFalsy())
                    }

                    it("should import the feed") {
                        expect(dataManager.newFeedURL).to(equal("http://example.com/feed"))
                    }

                    describe("when it's done importing the feeds") {
                        beforeEach {
                            dataManager.newFeedCompletion(nil)
                        }

                        it("should remove the activity indicator") {
                            expect(subject.view.subviews).toNot(contain(ActivityIndicator.self))
                        }

                        it("should re-enable user interaction") {
                            expect(subject.view.userInteractionEnabled).to(beTruthy())
                        }

                        it("should re-enable the dismiss button") {
                            expect(subject.navigationItem.leftBarButtonItem?.enabled).to(beTruthy())
                        }
                    }
                }
            }
        }
    }
}

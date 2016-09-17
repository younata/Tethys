
import Quick
import Nimble
import Ra
import Muon
import rNews
import rNewsKit

private func createOPMLWithFeeds(feeds: [(url: String, title: String)], location: String) {
    var opml = "<opml><body>"
    for feed in feeds {
        opml += "<outline xmlURL=\"\(feed.url)\" title=\"\(feed.title)\" type=\"rss\"/>"
    }
    opml += "</body></opml>"

    let path = documentsDirectory() + "/" + location
    do {
        try opml.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
    } catch _ {
    }
}

private func deleteAtLocation(location: String) {
    let path = documentsDirectory() + "/" + location
    do {
        try FileManager.default.removeItem(atPath: path)
    } catch _ {
    }
}

private func createFeed(feed: (url: String, title: String, articles: [String]), location: String) {
    var str = "<rss><channel><title>\(feed.title)</title><link>\(feed.url)</link>"
    for article in feed.articles {
        str += "<item><title>\(article)</title></item>"
    }
    str += "</channel></rss>"

    let path = documentsDirectory() + "/" + location
    do {
        try str.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
    } catch _ {
    }
}

private let documentsUrl = URL(string: "file://\(NSHomeDirectory())/Documents/")!

class LocalImportViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: LocalImportViewController! = nil
        var injector: Ra.Injector! = nil

        var navigationController: UINavigationController! = nil

        var tableView: UITableView! = nil

        var themeRepository: ThemeRepository!
        var importUseCase: FakeImportUseCase!
        var analytics: FakeAnalytics!

        beforeEach {
            injector = Ra.Injector()

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            analytics = FakeAnalytics()
            injector.bind(kind: Analytics.self, toInstance: analytics)

            importUseCase = FakeImportUseCase()
            injector.bind(kind: ImportUseCase.self, toInstance: importUseCase)

            subject = injector.create(kind: LocalImportViewController.self)!

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
            tableView = subject.tableViewController.tableView
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should update the tableView") {
                expect(subject.tableViewController.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                expect(subject.tableViewController.tableView.separatorColor).to(equal(themeRepository.textColor))
            }

            it("should update the scroll indicator style") {
                expect(subject.tableViewController.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
            }

            it("should update the navigation bar background") {
                expect(navigationController.navigationBar.barStyle).to(equal(themeRepository.barStyle))
            }
        }

        it("asks the use case to scan for any importable items in the documents directory") {
            expect(importUseCase.scanDirectoryForImportablesCallCount) == 1
            expect(importUseCase.scanDirectoryForImportablesArgsForCall(callIndex: 0).0) == documentsUrl
        }

        it("tells analytics to log that the user viewed LocalImport") {
            expect(analytics.logEventCallCount) == 1
            expect(analytics.logEventArgsForCall(0).0) == "DidViewLocalImport"
            expect(analytics.logEventArgsForCall(0).1).to(beNil())
        }

        describe("the explanation message") {
            let itShowsAnExplanationMessage = {
                it("shows the explanationLabel") {
                    expect(subject.explanationLabel.superview).toNot(beNil())
                }

                context("when feeds are added") {

                    beforeEach {
                        let opmlUrl = documentsUrl.appendingPathComponent("rnews.opml")
                        let feedUrl = documentsUrl.appendingPathComponent("feed")

                        subject.reloadItems()

                        importUseCase.scanDirectoryForImportablesArgsForCall(callIndex: 1).1([.opml(opmlUrl, 3), .feed(feedUrl, 10)])
                    }

                    it("removes the explanationLabel from the view hierarchy") {
                        expect(subject.explanationLabel.superview).to(beNil())
                    }
                }
            }

            context("when there are no files to list") {
                beforeEach {
                    importUseCase.scanDirectoryForImportablesArgsForCall(callIndex: 0).1([])
                }

                itShowsAnExplanationMessage()
            }

            context("when there is only the rnews.opml file to list") {
                beforeEach {
                    let opmlUrl = documentsUrl.appendingPathComponent("rnews.opml")
                    importUseCase.scanDirectoryForImportablesArgsForCall(callIndex: 0).1([.opml(opmlUrl, 3)])
                }

                itShowsAnExplanationMessage()
            }

            context("when there are multiple files to list") {
                beforeEach {
                    let opmlUrl = documentsUrl.appendingPathComponent("rnews.opml")
                    let feedUrl = documentsUrl.appendingPathComponent("feed")

                    importUseCase.scanDirectoryForImportablesArgsForCall(callIndex: 0).1([.opml(opmlUrl, 3), .feed(feedUrl, 10)])
                }
                
                it("does not show the explanationLabel") {
                    expect(subject.explanationLabel.superview).to(beNil())
                }
            }
        }

        describe("the tableView") {
            let opmlUrl = documentsUrl.appendingPathComponent("rnews.opml")
            let feedUrl = documentsUrl.appendingPathComponent("feed")

            beforeEach {
                importUseCase.scanDirectoryForImportablesArgsForCall(callIndex: 0).1([.opml(opmlUrl, 3), .feed(feedUrl, 10)])
            }

            it("should have 2 sections") {
                expect(subject.numberOfSections(in: tableView)).to(equal(2))
            }

            it("should with 1 row in each section") {
                expect(subject.tableView(tableView, numberOfRowsInSection: 0)).to(equal(1))
                expect(subject.tableView(tableView, numberOfRowsInSection: 1)).to(equal(1))
            }

            it("should now label sections") {
                let opmlHeader = subject.tableView(tableView, titleForHeaderInSection: 0)
                let feedHeader = subject.tableView(tableView, titleForHeaderInSection: 1)
                expect(opmlHeader).to(equal("Feed Lists"))
                expect(feedHeader).to(equal("Individual Feeds"))
            }

            describe("the cell in section 0") {
                var cell : UITableViewCell? = nil
                let indexPath = IndexPath(row: 0, section: 0)
                beforeEach {
                    expect(subject.numberOfSections(in: tableView)).to(beGreaterThan(indexPath.section))
                    if subject.numberOfSections(in: tableView) > indexPath.section {
                        expect(subject.tableView(tableView, numberOfRowsInSection: indexPath.section)).to(beGreaterThan(indexPath.row))
                        if subject.tableView(tableView, numberOfRowsInSection: indexPath.section) > indexPath.row {
                            cell = subject.tableView(tableView, cellForRowAt: indexPath)
                        }
                    }
                }

                it("should be named for the file name") {
                    expect(cell?.textLabel?.text).to(equal("rnews.opml"))
                }

                it("should list how many feeds are in this opml file") {
                    expect(cell?.detailTextLabel?.text).to(equal("3 feeds"))
                }

                describe("selecting it") {
                    beforeEach {
                        subject.tableView(tableView, didSelectRowAt: indexPath)
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

                    it("tells the use case to import the opml") {
                        expect(importUseCase.importItemArgsForCall(callIndex: 0).0) == opmlUrl
                    }

                    describe("when the import finishes") {
                        beforeEach {
                            importUseCase.importItemArgsForCall(callIndex: 0).1()
                        }
                        it("tells analytics to log that the user used LocalImport") {
                            expect(analytics.logEventCallCount) == 2
                            expect(analytics.logEventArgsForCall(1).0) == "DidUseLocalImport"
                            expect(analytics.logEventArgsForCall(1).1) == ["kind": "feed"]
                        }

                        it("dismisses the activity indicator") {
                            let subjectHasNoActivityIndicator = subject.view.subviews.filter { return $0.classForCoder == ActivityIndicator.classForCoder() }.count == 0
                            expect(subjectHasNoActivityIndicator).to(beTruthy())
                        }
                    }
                }
            }

            describe("the cell in section 1") {
                var cell : UITableViewCell! = nil
                let indexPath = IndexPath(row: 0, section: 1)
                beforeEach {
                    cell = subject.tableView(tableView, cellForRowAt: indexPath)
                }

                it("should be named for the file name") {
                    expect(cell.textLabel?.text).to(equal("feed"))
                }

                it("should list how many articles are in this feed") {
                    expect(cell.detailTextLabel?.text).to(equal("10 articles"))
                }

                describe("selecting it") {
                    beforeEach {
                        subject.tableView(tableView, didSelectRowAt: indexPath)
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

                    it("tells the use case to import the feed") {
                        expect(importUseCase.importItemArgsForCall(callIndex: 0).0) == feedUrl
                    }

                    describe("when the import finishes") {
                        beforeEach {
                            importUseCase.importItemArgsForCall(callIndex: 0).1()
                        }
                        it("tells analytics to log that the user used LocalImport") {
                            expect(analytics.logEventCallCount) == 2
                            expect(analytics.logEventArgsForCall(1).0) == "DidUseLocalImport"
                            expect(analytics.logEventArgsForCall(1).1) == ["kind": "opml"]
                        }

                        it("dismisses the activity indicator") {
                            let subjectHasNoActivityIndicator = subject.view.subviews.filter { return $0.classForCoder == ActivityIndicator.classForCoder() }.count == 0
                            expect(subjectHasNoActivityIndicator).to(beTruthy())
                        }
                    }
                }
            }
        }
    }
}

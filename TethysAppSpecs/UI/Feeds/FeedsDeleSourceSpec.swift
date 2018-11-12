import Quick
import Nimble
import Tethys
import TethysKit

class FeedsDeleSourceSpec: QuickSpec {
    override func spec() {
        var subject: FeedsDeleSource!

        var tableView: UITableView!
        var feedsSource: FakeFeedsSource!
        var themeRepository: ThemeRepository!
        var navigationController: UINavigationController!
        var mainQueue: FakeOperationQueue!
        var articleListFactory: ((Void) -> (ArticleListController))!
        var articleListFactoryCallCount = 0

        let feed1 = Feed(title: "a", url: URL(string: "http://example.com/feed")!, summary: "",
                         tags: ["a", "b", "c"], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
        var feeds: [Feed] = []

        beforeEach {
            tableView = UITableView()
            feedsSource = FakeFeedsSource()
            themeRepository = ThemeRepository(userDefaults: nil)
            navigationController = UINavigationController(rootViewController: UIViewController())

            articleListFactoryCallCount = 0

            feeds = [feed1]

            feedsSource.feeds = feeds

            articleListFactory = {
                articleListFactoryCallCount += 1
                return ArticleListController(
                    mainQueue: mainQueue,
                    feedRepository: FakeDatabaseUseCase(),
                    themeRepository: themeRepository,
                    settingsRepository: SettingsRepository(userDefaults: nil),
                    articleViewController: { fatalError() },
                    generateBookViewController: { fatalError() }
                )
            }

            mainQueue = FakeOperationQueue()

            subject = FeedsDeleSource(
                tableView: tableView,
                feedsSource: feedsSource,
                themeRepository: themeRepository,
                navigationController: navigationController,
                mainQueue: mainQueue,
                articleListController: articleListFactory
            )


            tableView.delegate = subject
            tableView.dataSource = subject
            tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
            tableView.reloadData()
        }

        it("should have a row for each feed") {
            expect(subject.tableView(tableView, numberOfRowsInSection: 0)) == feeds.count
        }

        describe("a cell") {
            var cell: FeedTableCell? = nil
            var feed: Feed! = nil

            context("for a regular feed") {
                beforeEach {
                    cell = subject.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as? FeedTableCell
                    feed = feeds[0]

                    expect(cell).to(beAnInstanceOf(FeedTableCell.self))
                }

                it("should be configured with the theme repository") {
                    expect(cell?.themeRepository).to(beIdenticalTo(themeRepository))
                }

                it("should be configured with the feed") {
                    expect(cell?.feed) == feed
                }

                describe("tapping on a cell") {
                    beforeEach {
                        let indexPath = IndexPath(row: 0, section: 0)
                        if let _ = cell {
                            subject.tableView(tableView, didSelectRowAt: indexPath)
                        }
                    }

                    it("should navigate to an ArticleListViewController for that feed") {
                        expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                        if let articleList = navigationController.topViewController as? ArticleListController {
                            expect(articleList.feed) == feed
                        }
                    }

                    it("calls selectFeed on the feedsSource") {
                        expect(feedsSource.selectFeedCallCount) == 1
                        expect(feedsSource.selectFeedArgsForCall(callIndex: 0)) == feed
                    }
                }

                describe("force pressing a cell") {
                    var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                    var viewController: UIViewController? = nil

                    beforeEach {
                        viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: tableView, sourceRect: CGRect.zero, delegate: subject)

                        let rect = tableView.rectForRow(at: IndexPath(row: 0, section: 0))
                        let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                        viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                    }

                    it("returns an ArticleListController configured with the feed's articles to present to the user") {
                        expect(viewController).to(beAKindOf(ArticleListController.self))
                        if let articleVC = viewController as? ArticleListController {
                            expect(articleVC.feed) == feed
                        }
                    }

                    describe("preview actions") {
                        var previewActions: [UIPreviewActionItem]?
                        var action: UIPreviewAction?
                        beforeEach {
                            expect(viewController).to(beAKindOf(ArticleListController.self))
                            previewActions = viewController?.previewActionItems
                            expect(previewActions).toNot(beNil())
                        }

                        it("has 4 preview actions") {
                            expect(previewActions?.count) == 4
                        }

                        describe("the first action") {
                            beforeEach {
                                action = previewActions?.first as? UIPreviewAction
                            }

                            it("states it marks all items in the feed as read") {
                                expect(action?.title).to(equal("Mark Read"))
                            }

                            describe("tapping it") {
                                beforeEach {
                                    action?.handler(action!, viewController!)
                                }

                                it("calls markRead on the feedsSource") {
                                    expect(feedsSource.markReadCallCount) == 1
                                }
                            }
                        }

                        describe("the second action") {
                            beforeEach {
                                if previewActions!.count > 1 {
                                    action = previewActions?[1] as? UIPreviewAction
                                }
                            }

                            it("states it edits the feed") {
                                expect(action?.title).to(equal("Edit"))
                            }

                            describe("tapping it") {
                                beforeEach {
                                    action?.handler(action!, viewController!)
                                }

                                it("calls editFeed on the feedsSource") {
                                    expect(feedsSource.editFeedCallCount) == 1
                                }
                            }
                        }

                        describe("the third action") {
                            beforeEach {
                                if previewActions!.count > 2 {
                                    action = previewActions?[2] as? UIPreviewAction
                                }
                            }

                            it("states it opens a share sheet") {
                                expect(action?.title).to(equal("Share"))
                            }

                            describe("tapping it") {
                                beforeEach {
                                    action?.handler(action!, viewController!)
                                }

                                it("calls shareFeed on the feedsSource") {
                                    expect(feedsSource.shareFeedCallCount) == 1
                                }
                            }
                        }

                        describe("the fourth action") {
                            beforeEach {
                                if previewActions!.count > 3 {
                                    action = previewActions?[3] as? UIPreviewAction
                                }
                            }

                            it("states it deletes the feed") {
                                expect(action?.title).to(equal("Delete"))
                            }

                            describe("tapping it") {
                                beforeEach {
                                    action?.handler(action!, viewController!)
                                }

                                it("calls deleteFeed on the feedsSource") {
                                    expect(feedsSource.deleteFeedCallCount) == 1
                                }
                            }
                        }
                    }

                    it("pushes the view controller when commited") {
                        if let vc = viewController {
                            subject.previewingContext(viewControllerPreviewing, commit: vc)
                            expect(navigationController.topViewController) === viewController
                        }
                    }
                }

                describe("exposing edit actions") {
                    var actions: [UITableViewRowAction]? = []
                    var action: UITableViewRowAction? = nil
                    let indexPath = IndexPath(row: 0, section: 0)

                    context("in preview mode") {
                        beforeEach {
                            subject.previewMode = true

                            action = nil
                            if let _ = cell {
                                actions = subject.tableView(tableView, editActionsForRowAt: indexPath)
                            }
                        }

                        it("has no edit actions") {
                            expect(actions).to(beNil())
                        }
                    }

                    context("not in preview mode") { // the default
                        beforeEach {
                            action = nil
                            if let _ = cell {
                                actions = subject.tableView(tableView, editActionsForRowAt: indexPath) ?? []
                            }
                        }

                        it("should have 4 actions") {
                            expect(actions?.count) == 4
                        }

                        describe("the first action") {
                            beforeEach {
                                action = actions?.first
                            }

                            it("states it deletes the feed") {
                                expect(action?.title).to(equal("Delete"))
                            }

                            describe("tapping it") {
                                beforeEach {
                                    action?.handler?(action!, indexPath)
                                }

                                it("calls deleteFeed on the feedsSource") {
                                    expect(feedsSource.deleteFeedCallCount) == 1
                                }
                            }
                        }

                        describe("the second action") {
                            beforeEach {
                                if actions!.count > 1 {
                                    action = actions![1]
                                }
                            }

                            it("states it marks all items in the feed as read") {
                                expect(action?.title).to(equal("Mark\nRead"))
                            }

                            describe("tapping it") {
                                beforeEach {
                                    action?.handler?(action!, indexPath)
                                }

                                it("calls markRead on the feedsSource") {
                                    expect(feedsSource.markReadCallCount) == 1
                                }

                                it("adds an operation to the mainQueue when the markRead promise resolves") {
                                    feedsSource.markReadPromises.last?.resolve(Void())
                                    expect(mainQueue.operationCount) == 1
                                }
                            }
                        }

                        describe("the third action") {
                            beforeEach {
                                if actions!.count > 2 {
                                    action = actions![2]
                                }
                            }

                            it("states it edits the feed") {
                                expect(action?.title).to(equal("Edit"))
                            }

                            describe("tapping it") {
                                beforeEach {
                                    action?.handler?(action!, indexPath)
                                }

                                it("calls editFeed on the feedsSource") {
                                    expect(feedsSource.editFeedCallCount) == 1
                                }
                            }
                        }

                        describe("the fourth action") {
                            beforeEach {
                                if actions!.count > 3 {
                                    action = actions![3]
                                }
                            }
                            
                            it("states it opens a share sheet") {
                                expect(action?.title).to(equal("Share"))
                            }
                            
                            describe("tapping it") {
                                beforeEach {
                                    action?.handler?(action!, indexPath)
                                }
                                
                                it("calls shareFeed on the feedsSource") {
                                    expect(feedsSource.shareFeedCallCount) == 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

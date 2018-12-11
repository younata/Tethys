import Quick
import Nimble
import Tethys
import BreakOutToRefresh
import TethysKit
import Result
import UIKit_PivotalSpecHelperStubs
import CBGPromise

final class FeedListControllerSpec: QuickSpec {
    override func spec() {
        var subject: FeedListController!
        var feedService: FakeFeedService!
        var navigationController: UINavigationController!
        var themeRepository: ThemeRepository!
        var settingsRepository: SettingsRepository!
        var mainQueue: FakeOperationQueue!

        let feeds: [Feed] = [
            feedFactory(title: "a"),
            feedFactory(title: "b"),
            feedFactory(title: "c")
        ]

        beforeEach {
            feedService = FakeFeedService()
            mainQueue = FakeOperationQueue()
            settingsRepository = SettingsRepository(userDefaults: nil)
            themeRepository = ThemeRepository(userDefaults: nil)

            subject = FeedListController(
                feedService: feedService,
                themeRepository: themeRepository,
                settingsRepository: settingsRepository,
                mainQueue: mainQueue,
                findFeedViewController: {
                    return FindFeedViewController(
                        importUseCase: FakeImportUseCase(),
                        themeRepository: themeRepository,
                        analytics: FakeAnalytics()
                    )
                },
                feedViewController: { feed in
                    return feedViewControllerFactory(feed: feed)
                },
                settingsViewController: { settingsViewControllerFactory() },
                articleListController: { feed in articleListControllerFactory(feed: feed) }
            )

            navigationController = UINavigationController(rootViewController: subject)
        }

        describe("when the view loads") {
            beforeEach {
                expect(subject.view).toNot(beNil())
                subject.viewWillAppear(false)
            }

            it("dismisses the keyboard upon drag") {
                expect(subject.view).toNot(beNil())
                expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollViewKeyboardDismissMode.onDrag))
            }

            describe("listening to theme repository updates") {
                beforeEach {
                    themeRepository.theme = .dark
                }

                it("updates the tableView") {
                    expect(subject.tableView.backgroundColor).to(equal(themeRepository.backgroundColor))
                    expect(subject.tableView.separatorColor).to(equal(themeRepository.textColor))
                }

                it("updates the tableView scroll indicator style") {
                    expect(subject.tableView.indicatorStyle).to(equal(themeRepository.scrollIndicatorStyle))
                }

                it("updates the navigation bar") {
                    expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                    expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
                }
            }

            describe("Key Commands") {
                it("can become first responder") {
                    expect(subject.canBecomeFirstResponder) == true
                }

                it("have a list of key commands") {
                    let keyCommands = subject.keyCommands
                    expect(keyCommands).toNot(beNil())
                    guard let commands = keyCommands else {
                        return
                    }

                    // cmd+i, cmd+shift+i, cmd+opt+i
                    let expectedCommands = [
                        UIKeyCommand(input: "i", modifierFlags: .command, action: #selector(BlankTarget.blank)),
                        UIKeyCommand(input: ",", modifierFlags: .command, action: #selector(BlankTarget.blank)),
                        ]
                    let expectedDiscoverabilityTitles = [
                        "Add from Web",
                        "Open settings",
                    ]

                    expect(commands.count).to(equal(expectedCommands.count))
                    for (idx, cmd) in commands.enumerated() {
                        let expectedCmd = expectedCommands[idx]
                        expect(cmd.input).to(equal(expectedCmd.input))
                        expect(cmd.modifierFlags).to(equal(expectedCmd.modifierFlags))

                        let expectedTitle = expectedDiscoverabilityTitles[idx]
                        expect(cmd.discoverabilityTitle).to(equal(expectedTitle))
                    }
                }
            }

            describe("the navigation bar items") {
                it("has one item on the right side") {
                    expect(subject.navigationItem.leftBarButtonItems ?? []).to(haveCount(1))
                }

                describe("the left bar button items") {
                    it("has one item on the left side") {
                        expect(subject.navigationItem.leftBarButtonItems ?? []).to(haveCount(1))
                    }

                    describe("tapping the settings button") {
                        beforeEach {
                            subject.navigationItem.leftBarButtonItem?.tap()
                        }

                        it("presents a settings page") {
                            expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                            if let nc = subject.presentedViewController as? UINavigationController {
                                expect(nc.topViewController).to(beAnInstanceOf(SettingsViewController.self))
                            }
                        }
                    }
                }

                describe("the right bar button items") {
                    it("has one item on the right side") {
                        expect(subject.navigationItem.rightBarButtonItems ?? []).to(haveCount(2))
                    }

                    describe("tapping the add feed button") {
                        beforeEach {
                            subject.navigationItem.rightBarButtonItems?.first?.tap()
                        }

                        afterEach {
                            navigationController.popToRootViewController(animated: false)
                        }

                        it("presents a FindFeedViewController") {
                            expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                            if let nc = subject.presentedViewController as? UINavigationController {
                                expect(nc.topViewController).to(beAnInstanceOf(FindFeedViewController.self))
                            }
                        }
                    }

                    it("has the edit button as the second one") {
                        expect(subject.navigationItem.rightBarButtonItems?.last?.title).to(equal("Edit"))
                    }
                }
            }

            it("shows an activity indicator") {
                expect(subject.loadingView.superview).toNot(beNil())
                expect(subject.loadingView.message).to(equal("Loading Feeds"))
            }

            it("asks the feed service to fetch the feeds") {
                expect(feedService.feedsPromises).to(haveCount(1))
            }

            it("starts refreshing") {
                expect(subject.refreshControl.isRefreshing).to(beTrue())
            }

            describe("when the feed service resolves successfully") {
                context("with a set of feeds") {
                    beforeEach {
                        feedService.feedsPromises.last?.resolve(.success(AnyCollection(feeds)))
                    }

                    it("shows a row for each returned feed") {
                        expect(subject.tableView.numberOfRows(inSection: 0)).to(equal(3))
                    }

                    it("stops refreshing") {
                        expect(subject.refreshControl.isRefreshing).to(beFalse())
                    }

                    it("removes the onboarding view") {
                        expect(subject.onboardingView.superview).to(beNil())
                    }

                    describe("pull to refresh") {
                        beforeEach {
                            subject.refreshControl.beginRefreshing()
                            subject.refreshControl.refreshViewDidRefresh(subject.refreshControl.breakoutView)
                        }

                        it("should tell the feedService to fetch new feeds") {
                            expect(feedService.feedsPromises).to(haveCount(2))
                            // already showed this behavior, so no point continuing to show it.
                        }

                        it("should be refreshing") {
                            expect(subject.refreshControl.isRefreshing).to(beTrue())
                        }
                    }

                    describe("the table") {
                        it("has a row for each feed") {
                            expect(subject.tableView.numberOfSections).to(equal(1))
                            expect(subject.tableView.numberOfRows(inSection: 0)).to(equal(3))
                        }

                        describe("a cell") {
                            var cell: FeedTableCell? = nil
                            var feed: Feed! = nil
                            let indexPath = IndexPath(row: 0, section: 0)

                            beforeEach {
                                cell = subject.tableView.cellForRow(at: indexPath) as? FeedTableCell
                                feed = feeds[0]

                                expect(cell).to(beAnInstanceOf(FeedTableCell.self))
                            }

                            it("should be configured with the theme repository") {
                                expect(cell?.themeRepository).to(beIdenticalTo(themeRepository))
                            }

                            it("should be configured with the feed") {
                                expect(cell?.feed) == feed
                            }

                            describe("tapping on it") {
                                beforeEach {
                                    let indexPath = IndexPath(row: 0, section: 0)
                                    if let _ = cell {
                                        subject.tableView.delegate?.tableView?(
                                            subject.tableView, didSelectRowAt: indexPath
                                        )
                                    }
                                }

                                it("should navigate to an ArticleListViewController for that feed") {
                                    expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                                    if let articleList = navigationController.topViewController as? ArticleListController {
                                        expect(articleList.feed) == feed
                                    }
                                }
                            }

                            describe("force pressing it") {
                                var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                                var viewController: UIViewController? = nil

                                beforeEach {
                                    viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                                    let rect = subject.tableView.rectForRow(at: IndexPath(row: 0, section: 0))
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

                                            it("marks all articles of that feed as read") {
                                                expect(feedService.readAllOfFeedCalls).to(equal([feeds[0]]))
                                            }

                                            describe("when the feed service succeeds") {
                                                beforeEach {
                                                    feedService.readAllOfFeedPromises.last?.resolve(.success())
                                                }

                                                xit("reloads the feed cell, indicating that it's unread count has changed") {
                                                    fail("Need to get rid of FeedDeleSource first")
                                                }
                                            }

                                            describe("when the feed service fails") {
                                                beforeEach {
                                                    UIView.pauseAnimations()
                                                    feedService.readAllOfFeedPromises.last?.resolve(.failure(.database(.unknown)))
                                                }

                                                afterEach {
                                                    UIView.resumeAnimations()
                                                }

                                                it("brings up an alert notifying the user") {
                                                    expect(subject.notificationView.titleLabel.isHidden) == false
                                                    expect(subject.notificationView.titleLabel.text).to(equal("Unable to update feed"))
                                                    expect(subject.notificationView.messageLabel.text).to(equal("Unknown Database Error"))
                                                }
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

                                            it("brings up a feed edit screen") {
                                                expect(navigationController.visibleViewController).to(beAnInstanceOf(UINavigationController.self))
                                                if let nc = navigationController.visibleViewController as? UINavigationController {
                                                    expect(nc.viewControllers.count).to(equal(1))
                                                    expect(nc.topViewController).to(beAnInstanceOf(FeedViewController.self))
                                                }
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

                                            it("brings up a share sheet") {
                                                expect(navigationController.visibleViewController).to(beAnInstanceOf(URLShareSheet.self))
                                                if let shareSheet = navigationController.visibleViewController as? URLShareSheet {
                                                    expect(shareSheet.url) == feeds[0].url
                                                    expect(shareSheet.themeRepository) == themeRepository
                                                    expect(shareSheet.activityItems as? [URL]) == [feeds[0].url]
                                                }
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

                                            it("does not yet delete the feed from the data store") {
                                                expect(feedService.removeFeedCalls).to(haveCount(0))
                                            }

                                            it("presents an alert asking for confirmation that the user wants to do this") {
                                                expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                                guard let alert = subject.presentedViewController as? UIAlertController else { return }
                                                expect(alert.preferredStyle) == UIAlertControllerStyle.alert
                                                expect(alert.title) == "Delete \(feeds[0].displayTitle)?"

                                                expect(alert.actions.count) == 2
                                                expect(alert.actions.first?.title) == "Delete"
                                                expect(alert.actions.last?.title) == "Cancel"
                                            }

                                            describe("tapping 'Delete'") {
                                                beforeEach {
                                                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                                    guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                                    alert.actions.first?.handler?(alert.actions.first!)
                                                }

                                                it("deletes the feed from the data store") {
                                                    expect(feedService.removeFeedCalls).to(equal([feeds[0]]))
                                                }

                                                it("dismisses the alert") {
                                                    expect(subject.presentedViewController).to(beNil())
                                                }

                                                describe("if the feedService successfully removes the feed") {
                                                    beforeEach {
                                                        feedService.removeFeedPromises.last?.resolve(.success())
                                                    }

                                                    it("removes the feed from the list of cells") {
                                                        expect(subject.tableView.numberOfRows(inSection: 0)).to(equal(2))
                                                    }
                                                }

                                                describe("if the feedService fails to remove the feed") {
                                                    beforeEach {
                                                        UIView.pauseAnimations()
                                                        feedService.removeFeedPromises.last?.resolve(.failure(.database(.unknown)))
                                                    }

                                                    afterEach {
                                                        UIView.resumeAnimations()
                                                    }

                                                    it("brings up an alert notifying the user") {
                                                        expect(subject.notificationView.titleLabel.isHidden) == false
                                                        expect(subject.notificationView.titleLabel.text).to(equal("Unable to delete feed"))
                                                        expect(subject.notificationView.messageLabel.text).to(equal("Unknown Database Error"))
                                                    }

                                                    it("does not remove the feed from the list of cells") {
                                                        expect(subject.tableView.numberOfRows(inSection: 0)).to(equal(3))
                                                    }
                                                }
                                            }

                                            describe("tapping 'Cancel'") {
                                                beforeEach {
                                                    expect(subject.presentedViewController).to(beAnInstanceOf(UIAlertController.self))
                                                    guard let alert = subject.presentedViewController as? UIAlertController else { return }

                                                    alert.actions.last?.handler?(alert.actions.last!)
                                                }

                                                it("does not delete the feed from the feed service") {
                                                    expect(feedService.removeFeedCalls).to(beEmpty())
                                                }

                                                it("dismisses the alert") {
                                                    expect(subject.presentedViewController).to(beNil())
                                                }
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
                        }
                    }
                }

                context("but no feeds were found") {
                    beforeEach {
                        feedService.feedsPromises.last?.resolve(.success(AnyCollection([])))
                    }

                    it("hides the activity indicator") {
                        expect(subject.loadingView.superview).to(beNil())
                    }

                    it("shows the onboarding view") {
                        expect(subject.onboardingView.superview).toNot(beNil())
                    }
                }
            }

            describe("when the feed service resolves with an error") {
                beforeEach {
                    UIView.pauseAnimations()
                    feedService.feedsPromises.last?.resolve(.failure(.database(.unknown)))
                }

                afterEach {
                    UIView.resumeAnimations()
                }

                it("brings up an alert notifying the user") {
                    expect(subject.notificationView.titleLabel.isHidden) == false
                    expect(subject.notificationView.titleLabel.text).to(equal("Unable to fetch feeds"))
                    expect(subject.notificationView.messageLabel.text).to(equal("Unknown Database Error"))
                }
            }
        }
    }
}

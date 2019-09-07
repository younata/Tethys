import Quick
import Nimble
import Tethys
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
        var notificationCenter: NotificationCenter!

        let feeds: [Feed] = [
            feedFactory(title: "a"),
            feedFactory(title: "b"),
            feedFactory(title: "c")
        ]

        var recorder: NotificationRecorder!

        beforeEach {
            feedService = FakeFeedService()
            mainQueue = FakeOperationQueue()
            settingsRepository = SettingsRepository(userDefaults: nil)
            settingsRepository.refreshControl = .spinner
            themeRepository = ThemeRepository(userDefaults: nil)
            notificationCenter = NotificationCenter()

            subject = FeedListController(
                feedService: feedService,
                themeRepository: themeRepository,
                settingsRepository: settingsRepository,
                mainQueue: mainQueue,
                notificationCenter: notificationCenter,
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

            recorder = NotificationRecorder()
            notificationCenter.addObserver(recorder!, selector: #selector(NotificationRecorder.received(notification:)),
                                           name: Notifications.reloadUI, object: subject)
        }

        describe("when the view loads") {
            beforeEach {
                expect(subject.view).toNot(beNil())

                // Make sure the refresh control has set the refresh control style.
                // Which requires running an operation on the main queue.
                expect(subject.refreshControl).toNot(beNil())
                mainQueue.runNextOperation()

                subject.viewWillAppear(false)
            }

            it("dismisses the keyboard upon drag") {
                expect(subject.view).toNot(beNil())
                expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollView.KeyboardDismissMode.onDrag))
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
                    expect(convertFromOptionalNSAttributedStringKeyDictionary(subject.navigationController?.navigationBar.titleTextAttributes) as? [String: UIColor]) == [convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): themeRepository.textColor]
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
                        (input: "i", modifierFlags: UIKeyModifierFlags.command),
                        (input: ",", modifierFlags: UIKeyModifierFlags.command),
                        (input: "r", modifierFlags: UIKeyModifierFlags.command),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Add from Web",
                        "Open settings",
                        "Reload Feeds",
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

                        it("pushes a settings page") {
                            expect(navigationController.visibleViewController).to(beAnInstanceOf(SettingsViewController.self))
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
                            expect(navigationController.visibleViewController).to(beAnInstanceOf(FindFeedViewController.self))
                        }
                    }

                    it("has the edit button as the second one") {
                        expect(subject.navigationItem.rightBarButtonItems?.last?.title).to(equal("Edit"))
                    }
                }
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
                            subject.refreshControl.spinner.sendActions(for: .valueChanged)
                        }

                        it("tells the feedService to fetch new feeds") {
                            expect(feedService.feedsPromises).to(haveCount(2))
                        }

                        it("refreshes") {
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
                                                    feedService.readAllOfFeedPromises.last?.resolve(.success(()))
                                                }

                                                it("marks the cell as unread") {
                                                    expect(cell?.unreadCounter.unread).to(equal(0))
                                                }

                                                it("posts a notification telling other things to reload") {
                                                    expect(recorder.notifications).to(haveCount(1))
                                                    expect(recorder.notifications.last?.object as? NSObject).to(be(subject))
                                                }

                                                it("does not tell the feedService to fetch new feeds") {
                                                    expect(feedService.feedsPromises).to(haveCount(1))
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

                                                it("doesn't post a notification telling other things to reload") {
                                                    expect(recorder.notifications).to(beEmpty())
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
                                                expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedViewController.self))
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

                                            it("deletes the feed from the data store") {
                                                expect(feedService.removeFeedCalls).to(equal([feeds[0]]))
                                            }

                                            describe("if the feedService successfully removes the feed") {
                                                beforeEach {
                                                    feedService.removeFeedPromises.last?.resolve(.success(()))
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
                                    }
                                }

                                it("pushes the view controller when commited") {
                                    if let vc = viewController {
                                        subject.previewingContext(viewControllerPreviewing, commit: vc)
                                        expect(navigationController.topViewController) === viewController
                                    }
                                }
                            }

                            describe("edit actions") {
                                var editActions: [UITableViewRowAction] = []

                                var action: UITableViewRowAction?

                                beforeEach {
                                    editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAt: indexPath) ?? []
                                }

                                it("has 4 edit actions") {
                                    expect(editActions).to(haveCount(4))
                                }

                                describe("the first one") {
                                    beforeEach {
                                        action = editActions.first
                                    }

                                    it("states it deletes the feed") {
                                        expect(action?.title).to(equal("Delete"))
                                    }

                                    describe("tapping it") {
                                        beforeEach {
                                            action?.handler?(action!, indexPath)
                                        }

                                        it("deletes the feed from the data store") {
                                            expect(feedService.removeFeedCalls).to(equal([feeds[0]]))
                                        }

                                        describe("if the feedService successfully removes the feed") {
                                            beforeEach {
                                                feedService.removeFeedPromises.last?.resolve(.success(()))
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
                                }

                                describe("the second one") {
                                    beforeEach {
                                        guard editActions.count > 1 else { return }
                                        action = editActions[1]
                                    }

                                    it("states it marks all items in the feed as read") {
                                        expect(action?.title).to(equal("Mark\nRead"))
                                    }

                                    describe("tapping it") {
                                        beforeEach {
                                            action?.handler?(action!, indexPath)
                                        }

                                        it("marks all articles of that feed as read") {
                                            expect(feedService.readAllOfFeedCalls).to(equal([feeds[0]]))
                                        }

                                        describe("when the feed service succeeds") {
                                            beforeEach {
                                                feedService.readAllOfFeedPromises.last?.resolve(.success(()))
                                            }

                                            it("marks the cell as unread") {
                                                expect(cell?.unreadCounter.unread).to(equal(0))
                                            }

                                            it("posts a notification telling other things to reload") {
                                                expect(recorder.notifications).to(haveCount(1))
                                                expect(recorder.notifications.last?.object as? NSObject).to(be(subject))
                                            }

                                            it("does not tell the feedService to fetch new feeds") {
                                                expect(feedService.feedsPromises).to(haveCount(1))
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

                                            it("doesn't post a notification") {
                                                expect(recorder.notifications).to(beEmpty())
                                            }
                                        }
                                    }
                                }

                                describe("the third one") {
                                    beforeEach {
                                        guard editActions.count > 2 else { return }
                                        action = editActions[2]
                                    }

                                    it("states it edits the feed") {
                                        expect(action?.title).to(equal("Edit"))
                                    }

                                    describe("tapping it") {
                                        beforeEach {
                                            action?.handler?(action!, indexPath)
                                        }

                                        it("brings up a feed edit screen") {
                                            expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedViewController.self))
                                        }
                                    }
                                }

                                describe("the fourth one") {
                                    beforeEach {
                                        guard editActions.count > 3 else { return }
                                        action = editActions[3]
                                    }

                                    it("states it opens a share sheet") {
                                        expect(action?.title).to(equal("Share"))
                                    }

                                    describe("tapping it") {
                                        beforeEach {
                                            action?.handler?(action!, indexPath)
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
                            }
                        }
                    }

                    describe("when the reloadUI notification is posted") {
                        beforeEach {
                            notificationCenter.post(name: Notifications.reloadUI, object: self)
                        }

                        it("tells the feedService to fetch new feeds") {
                            expect(feedService.feedsPromises).to(haveCount(2))
                        }
                    }
                }

                context("but no feeds were found") {
                    beforeEach {
                        feedService.feedsPromises.last?.resolve(.success(AnyCollection([])))
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

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSAttributedStringKeyDictionary(_ input: [NSAttributedString.Key: Any]?) -> [String: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

class NotificationRecorder: NSObject {
    var notifications: [Notification] = []

    @objc func received(notification: Notification) {
        self.notifications.append(notification)
    }
}

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
            notificationCenter = NotificationCenter()

            subject = FeedListController(
                feedService: feedService,
                settingsRepository: settingsRepository,
                mainQueue: mainQueue,
                notificationCenter: notificationCenter,
                findFeedViewController: {
                    return FindFeedViewController(
                        importUseCase: FakeImportUseCase(),
                        analytics: FakeAnalytics(),
                        notificationCenter: notificationCenter
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
                expect(mainQueue.operationCount).to(equal(3))
                mainQueue.runNextOperation()

                expect(mainQueue.operationCount).to(equal(2))
                mainQueue.runNextOperation()

                expect(mainQueue.operationCount).to(equal(1))
                mainQueue.runNextOperation()

                expect(mainQueue.operationCount).to(equal(0))

                subject.viewWillAppear(false)
            }

            it("dismisses the keyboard upon drag") {
                expect(subject.view).toNot(beNil())
                expect(subject.tableView.keyboardDismissMode).to(equal(UIScrollView.KeyboardDismissMode.onDrag))
            }

            describe("theming") {
                it("updates the tableView") {
                    expect(subject.tableView.backgroundColor).to(equal(Theme.backgroundColor))
                    expect(subject.tableView.separatorColor).to(equal(Theme.separatorColor))
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
                describe("the left bar button items") {
                    it("has one item on the left side") {
                        expect(subject.navigationItem.leftBarButtonItems ?? []).to(haveCount(1))
                    }

                    describe("the settings button") {
                        it("is enabled for accessibility") {
                            expect(subject.navigationItem.leftBarButtonItem?.isAccessibilityElement).to(beTrue())
                            expect(subject.navigationItem.leftBarButtonItem?.accessibilityLabel).to(equal("Settings"))
                            expect(subject.navigationItem.leftBarButtonItem?.accessibilityTraits).to(equal([.button]))
                        }

                        describe("tapping it") {
                            beforeEach {
                                subject.navigationItem.leftBarButtonItem?.tap()
                            }

                            it("presents a settings page") {
                                expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                                expect((subject.presentedViewController as? UINavigationController)?.visibleViewController).to(beAnInstanceOf(SettingsViewController.self))
                            }
                        }
                    }
                }

                describe("the right bar button items") {
                    it("has two items on the right side") {
                        expect(subject.navigationItem.rightBarButtonItems ?? []).to(haveCount(2))
                    }

                    describe("the add feed button") {
                        var addFeedButton: UIBarButtonItem?

                        beforeEach {
                            addFeedButton = subject.navigationItem.rightBarButtonItems?.first
                        }

                        it("is enabled for accessibility") {
                            expect(addFeedButton?.isAccessibilityElement).to(beTrue())
                            expect(addFeedButton?.accessibilityLabel).to(equal("Add feed"))
                            expect(addFeedButton?.accessibilityTraits).to(equal([.button]))
                        }

                        describe("tapping it") {
                            beforeEach {
                                addFeedButton?.tap()
                            }

                            afterEach {
                                navigationController.popToRootViewController(animated: false)
                            }

                            it("presents a FindFeedViewController") {
                                expect(subject.presentedViewController).to(beAnInstanceOf(UINavigationController.self))
                                expect((subject.presentedViewController as? UINavigationController)?.visibleViewController).to(beAnInstanceOf(FindFeedViewController.self))
                            }
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

                            it("is configured with the feed") {
                                expect(cell?.feed).to(equal(feed))
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
                                        expect(articleList.feed).to(equal(feed))
                                    }
                                }
                            }

                            describe("contextual menus") {
                                var menuConfiguration: UIContextMenuConfiguration?

                                beforeEach {
                                    menuConfiguration = subject.tableView.delegate?.tableView?(subject.tableView, contextMenuConfigurationForRowAt: indexPath, point: .zero)
                                }

                                it("shows a menu configured to show a set of articles") {
                                    expect(menuConfiguration).toNot(beNil())
                                    let viewController = menuConfiguration?.previewProvider?()
                                    expect(viewController).to(beAKindOf(ArticleListController.self))
                                    if let articleVC = viewController as? ArticleListController {
                                        expect(articleVC.feed) == feed
                                    }
                                }

                                describe("the menu items") {
                                    var menu: UIMenu?
                                    var action: UIAction?

                                    beforeEach {
                                        menu = menuConfiguration?.actionProvider?([])
                                    }

                                    it("has 4 children actions") {
                                        expect(menu?.children).to(haveCount(4))
                                        expect(menu?.children.compactMap { $0 as? UIAction }).to(haveCount(4))
                                    }

                                    describe("the first action") {
                                        beforeEach {
                                            action = menu?.children.first as? UIAction
                                        }

                                        it("states it marks all items in the feed as read") {
                                            expect(action?.title).to(equal("Mark Read"))
                                        }

                                        it("uses the mark read image") {
                                            expect(action?.image).to(equal(UIImage(named: "MarkRead")))
                                        }

                                        describe("tapping it") {
                                            beforeEach {
                                                action?.handler(action!)
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
                                            guard let menu = menu, menu.children.count > 1 else { return }
                                            action = menu.children[1] as? UIAction
                                        }

                                        it("states it edits the feed") {
                                            expect(action?.title).to(equal("Edit"))
                                        }

                                        describe("tapping it") {
                                            beforeEach {
                                                action?.handler(action!)
                                            }

                                            it("brings up a feed edit screen") {
                                                expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedViewController.self))
                                            }
                                        }
                                    }

                                    describe("the third action") {
                                        beforeEach {
                                            guard let menu = menu, menu.children.count > 2 else { return }
                                            action = menu.children[2] as? UIAction
                                        }

                                        it("states it opens a share sheet") {
                                            expect(action?.title).to(equal("Share"))
                                        }

                                        it("uses the share icon") {
                                            expect(action?.image).to(equal(UIImage(systemName: "square.and.arrow.up")))
                                        }

                                        describe("tapping it") {
                                            beforeEach {
                                                action?.handler(action!)
                                            }

                                            it("brings up a share sheet") {
                                                expect(navigationController.visibleViewController).to(beAnInstanceOf(UIActivityViewController.self))
                                                if let shareSheet = navigationController.visibleViewController as? UIActivityViewController {
                                                    expect(shareSheet.activityItems as? [URL]).to(equal([feeds[0].url]))
                                                }
                                            }
                                        }
                                    }

                                    describe("the fourth action") {
                                        beforeEach {
                                            guard let menu = menu, menu.children.count > 3 else { return }
                                            action = menu.children[3] as? UIAction
                                        }

                                        it("states it deletes the feed") {
                                            expect(action?.title).to(equal("Delete"))
                                        }

                                        it("uses a trash can icon") {
                                            expect(action?.image).to(equal(UIImage(systemName: "trash")))
                                        }

                                        describe("tapping it") {
                                            beforeEach {
                                                action?.handler(action!)
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

                                describe("committing the view controller (tapping on it again)") {
                                    beforeEach {
                                        guard let config = menuConfiguration else { return }
                                        let animator = FakeContextMenuAnimator(commitStyle: .pop, viewController: menuConfiguration?.previewProvider?())
                                        subject.tableView.delegate?.tableView?(subject.tableView, willPerformPreviewActionForMenuWith: config, animator: animator)

                                        expect(animator.addAnimationsCalls).to(beEmpty())
                                        expect(animator.addCompletionCalls).to(haveCount(1))
                                        animator.addCompletionCalls.last?()
                                    }

                                    it("navigates to the view controller") {
                                        expect(navigationController.topViewController).to(beAnInstanceOf(ArticleListController.self))
                                        if let articleVC = navigationController.topViewController as? ArticleListController {
                                            expect(articleVC.feed) == feed
                                        }
                                    }
                                }
                            }

                            describe("contextual actions") {
                                var contextualActions: [UIContextualAction] = []

                                var action: UIContextualAction?

                                beforeEach {
                                    let swipeActions = subject.tableView.delegate?.tableView?(subject.tableView, trailingSwipeActionsConfigurationForRowAt: indexPath)
                                    expect(swipeActions?.performsFirstActionWithFullSwipe).to(beTrue())
                                    contextualActions = swipeActions?.actions ?? []
                                }

                                it("has 4 edit actions") {
                                    expect(contextualActions).to(haveCount(4))
                                }

                                describe("the first one") {
                                    beforeEach {
                                        action = contextualActions.first
                                    }

                                    it("states it deletes the feed") {
                                        expect(action?.title).to(equal("Delete"))
                                    }

                                    describe("tapping it") {
                                        var completionHandlerCalls: [Bool] = []
                                        beforeEach {
                                            completionHandlerCalls = []
                                            action?.handler(action!, subject.tableView.cellForRow(at: indexPath)!) { completionHandlerCalls.append($0) }
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

                                            it("calls the completion handler") {
                                                expect(completionHandlerCalls).to(equal([true]))
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

                                            it("calls the completion handler") {
                                                expect(completionHandlerCalls).to(equal([false]))
                                            }
                                        }
                                    }
                                }

                                describe("the second one") {
                                    beforeEach {
                                        guard contextualActions.count > 1 else { return }
                                        action = contextualActions[1]
                                    }

                                    it("states it marks all items in the feed as read") {
                                        expect(action?.title).to(equal("Mark\nRead"))
                                    }

                                    describe("tapping it") {
                                        var completionHandlerCalls: [Bool] = []
                                        beforeEach {
                                            completionHandlerCalls = []
                                            action?.handler(action!, subject.tableView.cellForRow(at: indexPath)!) { completionHandlerCalls.append($0) }
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

                                            it("calls the completion handler") {
                                                expect(completionHandlerCalls).to(equal([true]))
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

                                            it("calls the completion handler") {
                                                expect(completionHandlerCalls).to(equal([false]))
                                            }
                                        }
                                    }
                                }

                                describe("the third one") {
                                    beforeEach {
                                        guard contextualActions.count > 2 else { return }
                                        action = contextualActions[2]
                                    }

                                    it("states it edits the feed") {
                                        expect(action?.title).to(equal("Edit"))
                                    }

                                    describe("tapping it") {
                                        var completionHandlerCalls: [Bool] = []
                                        beforeEach {
                                            completionHandlerCalls = []
                                            action?.handler(action!, subject.tableView.cellForRow(at: indexPath)!) { completionHandlerCalls.append($0) }
                                        }

                                        it("brings up a feed edit screen") {
                                            expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedViewController.self))
                                        }

                                        it("calls the completion handler") {
                                            expect(completionHandlerCalls).to(equal([true]))
                                        }
                                    }
                                }

                                describe("the fourth one") {
                                    beforeEach {
                                        guard contextualActions.count > 3 else { return }
                                        action = contextualActions[3]
                                    }

                                    it("states it opens a share sheet") {
                                        expect(action?.title).to(equal("Share"))
                                    }

                                    it("colors itself based on the theme's highlight color") {
                                        expect(action?.backgroundColor).to(equal(Theme.highlightColor))
                                    }

                                    describe("tapping it") {
                                        var completionHandlerCalls: [Bool] = []
                                        beforeEach {
                                            completionHandlerCalls = []
                                            action?.handler(action!, subject.tableView.cellForRow(at: indexPath)!) { completionHandlerCalls.append($0) }
                                        }

                                        it("brings up a share sheet") {
                                            expect(navigationController.visibleViewController).to(beAnInstanceOf(UIActivityViewController.self))
                                            if let shareSheet = navigationController.visibleViewController as? UIActivityViewController {
                                                expect(shareSheet.activityItems as? [URL]).to(equal([feeds[0].url]))
                                            }
                                        }

                                        it("calls the completion handler") {
                                            expect(completionHandlerCalls).to(equal([true]))
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

                    it("gives the onboarding view accessibility information") {
                        expect(subject.onboardingView.accessibilityLabel).to(equal("Usage"))
                        expect(subject.onboardingView.accessibilityValue).to(equal("Welcome to Tethys! Use the add button to search for feeds to follow"))
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

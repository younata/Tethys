import Quick
import Nimble
import Tethys
import TethysKit
import Ra
import SafariServices

class SettingsViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SettingsViewController! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: ThemeRepository! = nil
        var feedRepository: FakeDatabaseUseCase! = nil
        var settingsRepository: SettingsRepository! = nil
        var fakeQuickActionRepository: FakeQuickActionRepository! = nil
        var accountRepository: FakeAccountRepository! = nil
        var opmlService: FakeOPMLService! = nil

        beforeEach {
            let injector = Injector()

            themeRepository = ThemeRepository(userDefaults: nil)
            injector.bind(ThemeRepository.self, to: themeRepository)

            settingsRepository = SettingsRepository(userDefaults: nil)
            injector.bind(SettingsRepository.self, to: settingsRepository)

            fakeQuickActionRepository = FakeQuickActionRepository()
            injector.bind(QuickActionRepository.self, to: fakeQuickActionRepository)

            feedRepository = FakeDatabaseUseCase()
            injector.bind(DatabaseUseCase.self, to: feedRepository)

            accountRepository = FakeAccountRepository()
            accountRepository.loggedInReturns(nil)
            injector.bind(AccountRepository.self, to: accountRepository)
            let mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            injector.bind(kMainQueue, to: mainQueue)

            opmlService = FakeOPMLService()
            injector.bind(OPMLService.self, to: opmlService)

            injector.bind(DocumentationUseCase.self, to: FakeDocumentationUseCase())

            subject = injector.create(SettingsViewController.self)!

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should restyle the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
                expect(subject.navigationController?.navigationBar.titleTextAttributes as? [String: UIColor]) == [NSForegroundColorAttributeName: themeRepository.textColor]
            }

            it("by changing the background color of the tableView") {
                expect(subject.tableView.backgroundColor) == UIColor.black
            }

            it("should change the background color of the view") {
                expect(subject.view.backgroundColor) == themeRepository.backgroundColor
            }
        }

        it("is titled 'Settings'") {
            expect(subject.navigationItem.title) == "Settings"
        }

        it("has a disabled save button") {
            expect(subject.navigationItem.rightBarButtonItem?.isEnabled) == false
        }

        describe("tapping the cancel button") {
            var rootViewController: UIViewController! = nil
            beforeEach {
                rootViewController = UIViewController()
                rootViewController.present(navigationController, animated: false, completion: nil)
                expect(rootViewController.presentedViewController).to(beIdenticalTo(navigationController))

                subject.navigationItem.leftBarButtonItem?.tap()
            }

            it("dismisses itself") {
                expect(rootViewController.presentedViewController).to(beNil())
            }
        }

        sharedExamples("a changed setting") { (sharedContext: @escaping SharedExampleContext) in
            it("should enable the save button") {
                expect(subject.navigationItem.rightBarButtonItem?.isEnabled) == true
            }

            describe("tapping the save button") {
                var rootViewController: UIViewController! = nil
                beforeEach {
                    rootViewController = UIViewController()
                    rootViewController.present(navigationController, animated: false, completion: nil)
                    expect(rootViewController.presentedViewController).toNot(beNil())

                    subject.navigationItem.rightBarButtonItem?.tap()
                }

                it("dismisses itself") {
                    expect(rootViewController.presentedViewController).to(beNil())
                }

                it("saves the change to the userDefaults") {
                    let op = sharedContext()["saveToUserDefaults"] as? Operation
                    op?.main()
                }
            }
        }

        describe("key commands") {
            it("can become first responder") {
                expect(subject.canBecomeFirstResponder) == true
            }

            it("has (number of themes - 1) + 2 commands") {
                let keyCommands = subject.keyCommands
                expect(keyCommands?.count) == 3
            }

            describe("the first (number of themes - 1) commands") {
                context("when .light is the current theme") {
                    beforeEach {
                        themeRepository.theme = .light
                    }

                    it("lists every other theme but .light") {
                        let keyCommands = subject.keyCommands
                        expect(keyCommands).toNot(beNil())
                        guard let commands = keyCommands else {
                            return
                        }

                        let expectedCommands = [
                            UIKeyCommand(input: "2", modifierFlags: .command, action: #selector(BlankTarget.blank)),
                        ]
                        let expectedDiscoverabilityTitles = [
                            "Change Theme to 'Dark'",
                        ]

                        for (idx, expectedCmd) in expectedCommands.enumerated() {
                            let cmd = commands[idx]
                            expect(cmd.input) == expectedCmd.input
                            expect(cmd.modifierFlags) == expectedCmd.modifierFlags

                            let expectedTitle = expectedDiscoverabilityTitles[idx]
                            expect(cmd.discoverabilityTitle) == expectedTitle
                        }
                    }
                }

                context("when .dark is the current theme") {
                    beforeEach {
                        themeRepository.theme = .dark
                    }

                    it("lists every other theme but .dark") {
                        let keyCommands = subject.keyCommands
                        expect(keyCommands).toNot(beNil())
                        guard let commands = keyCommands else {
                            return
                        }

                        let expectedCommands = [
                            UIKeyCommand(input: "1", modifierFlags: .command, action: #selector(BlankTarget.blank)),
                        ]
                        let expectedDiscoverabilityTitles = [
                            "Change Theme to 'Light'",
                        ]

                        for (idx, expectedCmd) in expectedCommands.enumerated() {
                            let cmd = commands[idx]
                            expect(cmd.input) == expectedCmd.input
                            expect(cmd.modifierFlags) == expectedCmd.modifierFlags

                            let expectedTitle = expectedDiscoverabilityTitles[idx]
                            expect(cmd.discoverabilityTitle) == expectedTitle
                        }
                    }
                }
            }

            describe("the last two commands") {
                it("it has commands for dismissing/saving") {
                    let keyCommands = subject.keyCommands
                    expect(keyCommands).toNot(beNil())
                    guard let allCommands = keyCommands else {
                        return
                    }

                    let commands = allCommands[allCommands.count - 2..<allCommands.count]

                    let expectedCommands = [
                        UIKeyCommand(input: "s", modifierFlags: .command, action: #selector(BlankTarget.blank)),
                        UIKeyCommand(input: "w", modifierFlags: .command, action: #selector(BlankTarget.blank)),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Save and dismiss",
                        "Dismiss without saving",
                    ]

                    expect(commands.count) == expectedCommands.count
                    for (idx, cmd) in commands.enumerated() {
                        let expectedCmd = expectedCommands[idx]
                        expect(cmd.input) == expectedCmd.input
                        expect(cmd.modifierFlags) == expectedCmd.modifierFlags

                        let expectedTitle = expectedDiscoverabilityTitles[idx]
                        expect(cmd.discoverabilityTitle) == expectedTitle
                    }
                }
            }
        }

        describe("the tableView") {
            var delegate: UITableViewDelegate! = nil
            var dataSource: UITableViewDataSource! = nil

            beforeEach {
                delegate = subject.tableView.delegate
                dataSource = subject.tableView.dataSource
            }

            it("has 6 sections if force touch is available") {
                subject.traitCollection.forceTouchCapability = UIForceTouchCapability.available
                subject.tableView.reloadData()
                expect(subject.tableView.numberOfSections) == 5
            }

            it("has 5 sections if force touch is not available") {
                subject.traitCollection.forceTouchCapability = UIForceTouchCapability.unavailable
                subject.tableView.reloadData()
                expect(subject.tableView.numberOfSections) == 4
            }

            describe("the theme section") {
                let sectionNumber = 0

                it("is titled 'Theme'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Theme"
                }

                it("has 2 cells") {
                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == 2
                }

                describe("the first cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = IndexPath(row: 0, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                    }

                    it("is titled 'Light'") {
                        expect(cell.textLabel?.text) == "Light"
                    }

                    it("has its theme repository set") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    it("is not selected") { // because it's not the current theme
                        expect(cell.isSelected) == false
                    }

                    it("has no edit actions") {
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAt: indexPath)).to(beNil())
                    }

                    describe("when tapped") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        describe("it previews the change") {
                            it("by restyling the navigation bar") {
                                expect(subject.navigationController?.navigationBar.barStyle) == UIBarStyle.default
                            }

                            it("by changing the background color of the tableView") {
                                expect(subject.tableView.backgroundColor).to(beNil())
                            }

                            it("by changing the background color of the view") {
                                expect(subject.view.backgroundColor) == UIColor.white
                            }
                        }

                        itBehavesLike("a changed setting") {
                            let op = BlockOperation {
                                expect(themeRepository.theme) == ThemeRepository.Theme.light
                            }
                            return ["saveToUserDefaults": op]
                        }
                    }

                    it("does not respond to 3d touch") {
                        let viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                        let rect = subject.tableView.rectForRow(at: indexPath)
                        let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                        let viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        expect(viewController).to(beNil())
                    }
                }

                describe("the second cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = IndexPath(row: 1, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                    }

                    it("is titled 'Dark (Default)'") {
                        expect(cell.textLabel?.text) == "Dark"
                    }

                    it("is selected if it's the current theme") { // which it is
                        expect(cell.isSelected) == true
                    }

                    it("has its theme repository set") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    it("has no edit actions") {
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAt: indexPath)).to(beNil())
                    }

                    it("does not respond to 3d touch") {
                        let viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                        let rect = subject.tableView.rectForRow(at: indexPath)
                        let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                        let viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        expect(viewController).to(beNil())
                    }
                }
            }

            describe("the refresh style section") {
                let sectionNumber = 1

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.unavailable
                }

                it("is titled 'Refresh Style'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Refresh Style"
                }

                it("has two cells") {
                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == 2
                }

                describe("the first cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = IndexPath(row: 0, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                    }

                    it("is titled 'Spinner'") {
                        expect(cell.textLabel?.text) == "Spinner"
                    }

                    it("is selected if it's the current refresh control style") { // which it is not
                        expect(cell.isSelected) == false
                    }

                    it("has its theme repository set") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    it("has no edit actions") {
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAt: indexPath)).to(beNil())
                    }

                    describe("when tapped") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }
                        itBehavesLike("a changed setting") {
                            let op = BlockOperation {
                                expect(settingsRepository.refreshControl) == RefreshControlStyle.spinner
                            }
                            return ["saveToUserDefaults": op]
                        }
                    }

                    it("does not respond to 3d touch") {
                        let viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                        let rect = subject.tableView.rectForRow(at: indexPath)
                        let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                        let viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        expect(viewController).to(beNil())
                    }
                }

                describe("the second cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = IndexPath(row: 1, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                    }

                    it("is titled 'Breakout'") {
                        expect(cell.textLabel?.text) == "Breakout"
                    }

                    it("has its theme repository set") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }
                    
                    it("has no edit actions") {
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAt: indexPath)).to(beNil())
                    }

                    it("does not respond to 3d touch") {
                        let viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                        let rect = subject.tableView.rectForRow(at: indexPath)
                        let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                        let viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        expect(viewController).to(beNil())
                    }
                }
            }

            describe("the quick actions section") {
                let sectionNumber = 2

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.available
                }

                it("is titled 'Quick Actions'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Quick Actions"
                }

                context("when there are no existing quick actions") {
                    beforeEach {
                        fakeQuickActionRepository.quickActions = []
                        subject.tableView.reloadData()
                    }

                    it("has a single cell, inviting the user to add a quick action") {
                        expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == 1

                        let indexPath = IndexPath(row: 0, section: sectionNumber)
                        let cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: indexPath)

                        expect(cell?.textLabel?.text) == "Add a Quick Action"
                    }

                    describe("tapping the add cell") {
                        let indexPath = IndexPath(row: 0, section: sectionNumber)

                        let feeds = [
                            Feed(title: "a", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
                            Feed(title: "b", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        ]

                        beforeEach {
                            subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("makes a request to the data use case for feeds") {
                            expect(feedRepository.feedsPromises.count) == 1
                        }

                        it("displays a list of feeds") {
                            expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedsListController.self))
                            if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                expect(feedsList.navigationItem.title) == "Add a Quick Action"
                                expect(feedsList.feeds.count) == 0
                            }
                        }

                        context("when the feeds promise succeeds") {
                            beforeEach {
                                feedRepository.feedsPromises.last?.resolve(.success(feeds))
                            }

                            it("sets the list of feeds") {
                                if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                    expect(feedsList.feeds.count) == feeds.count
                                    let feed = feeds[0]
                                    feedsList.tapFeed?(feed)
                                    expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                    expect(fakeQuickActionRepository.quickActions.count) == 1
                                    if let quickAction = fakeQuickActionRepository.quickActions.first {
                                        expect(quickAction.localizedTitle) == feed.displayTitle
                                        expect(quickAction.type) == "com.rachelbrindle.rssclient.viewfeed"
                                        expect(quickAction.userInfo?["feed"] as? String) == feed.title
                                    }
                                }
                            }
                        }

                        context("when the feeds promise fails") { // TODO: implement!

                        }
                    }

                    it("should not have any edit actions") {
                        let indexPath = IndexPath(row: 0, section: sectionNumber)

                        let editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAt: indexPath)
                        expect(editActions).to(beNil())
                    }

                    describe("3d touching the add feed cell") {
                        var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                        var viewController: UIViewController? = nil
                        let indexPath = IndexPath(row: 0, section: sectionNumber)

                        beforeEach {
                            subject.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
                            viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                            let rect = subject.tableView.rectForRow(at: indexPath)
                            let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                            viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        }

                        it("makes a request to the data use case for feeds") {
                            expect(feedRepository.feedsPromises.count) == 1
                        }

                        it("returns a FeedsListController") {
                            expect(viewController).to(beAnInstanceOf(FeedsListController.self))
                            if let feedsList = viewController as? FeedsListController {
                                expect(feedsList.navigationItem.title) == "Add a Quick Action"
                                expect(feedsList.feeds.count) == 0
                            }
                        }

                        it("has no preview actions") {
                            expect(viewController?.previewActionItems.count) == 0
                        }

                        it("pushes the feeds list controller if the user commits the touch") {
                            guard let vc = viewController else { fail(); return }
                            subject.previewingContext(viewControllerPreviewing, commit: vc)
                            expect(navigationController.visibleViewController) == vc
                        }

                        context("when the feeds promise succeeds") {
                            let feeds = [
                                Feed(title: "a", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
                                Feed(title: "b", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                            ]

                            beforeEach {
                                feedRepository.feedsPromises.last?.resolve(.success(feeds))
                            }

                            it("sets the list of feeds") {
                                if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                    expect(feedsList.feeds.count) == feeds.count
                                    let feed = feeds[0]
                                    feedsList.tapFeed?(feed)
                                    expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                    expect(fakeQuickActionRepository.quickActions.count) == 1
                                    if let quickAction = fakeQuickActionRepository.quickActions.first {
                                        expect(quickAction.localizedTitle) == feed.title
                                        expect(quickAction.type) == "com.rachelbrindle.rssclient.viewfeed"
                                        expect(quickAction.userInfo?["feed"] as? String) == feed.title
                                    }
                                }
                            }
                        }
                    }
                }

                context("when there are one or two existing quick actions") {
                    let feedA = Feed(title: "a", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feedB = Feed(title: "b", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    let feeds = [feedA, feedB]

                    beforeEach {
                        fakeQuickActionRepository.quickActions = [UIApplicationShortcutItem(type: "a", localizedTitle: "a")]
                        subject.tableView.reloadData()
                    }

                    it("should show the existing actions, plus an invitation to add one more") {
                        expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == 2
                        let firstIndexPath = IndexPath(row: 0, section: sectionNumber)
                        let firstCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: firstIndexPath)

                        expect(firstCell?.textLabel?.text) == "a"

                        let secondIndexPath = IndexPath(row: 1, section: sectionNumber)
                        let secondCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: secondIndexPath)

                        expect(secondCell?.textLabel?.text) == "Add a new Quick Action"
                    }

                    describe("the cell for an existing quick action") {
                        let indexPath = IndexPath(row: 0, section: sectionNumber)

                        describe("tapping it") {
                            beforeEach {
                                subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAt: indexPath)
                            }

                            it("makes a request to the data use case for feeds") {
                                expect(feedRepository.feedsPromises.count) == 1
                            }

                            it("displays a list of feeds cell") {
                                expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedsListController.self))

                                if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                    expect(feedsList.navigationItem.title) == feedA.title
                                }
                            }

                            context("when the feeds promise succeeds") {
                                beforeEach {
                                    feedRepository.feedsPromises.last?.resolve(.success(feeds))
                                }

                                it("should bring up a dialog to change the feed when one of the existing quick action cells is tapped") {
                                    expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedsListController.self))

                                    if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                        expect(feedsList.feeds) == [feedB]
                                        let feed = feeds[1]
                                        feedsList.tapFeed?(feed)
                                        expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                        expect(fakeQuickActionRepository.quickActions.count) == 1
                                        if let quickAction = fakeQuickActionRepository.quickActions.first {
                                            expect(quickAction.localizedTitle) == feed.title
                                            expect(quickAction.type) == "com.rachelbrindle.rssclient.viewfeed"
                                            expect(quickAction.userInfo?["feed"] as? String) == feed.title
                                        }
                                    }
                                }
                            }

                            context("when the feeds promise fails") { // TODO: implement!

                            }
                        }

                        describe("3d touching it") {
                            var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                            var viewController: UIViewController? = nil
                            let indexPath = IndexPath(row: 0, section: sectionNumber)

                            beforeEach {
                                subject.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
                                viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                                let rect = subject.tableView.rectForRow(at: indexPath)
                                let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                                viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                            }

                            it("makes a request to the data use case for feeds") {
                                expect(feedRepository.feedsPromises.count) == 1
                            }

                            it("returns a FeedsListController") {
                                expect(viewController).to(beAnInstanceOf(FeedsListController.self))
                                if let feedsList = viewController as? FeedsListController {
                                    expect(feedsList.navigationItem.title) == feedA.title
                                    expect(feedsList.feeds.count) == 0
                                }
                            }

                            describe("the preview actions") {
                                var previewActions: [UIPreviewActionItem]?
                                var action: UIPreviewAction?

                                beforeEach {
                                    previewActions = viewController?.previewActionItems
                                }

                                it("has 1 preview action") {
                                    expect(previewActions?.count) == 1
                                }

                                describe("the first action") {
                                    beforeEach {
                                        action = previewActions?.first as? UIPreviewAction
                                    }

                                    it("states that it deletes the quick action") {
                                        expect(action?.title) == "Delete"
                                    }

                                    describe("tapping it") {
                                        beforeEach {
                                            action?.handler(action!, viewController!)
                                        }

                                        it("deletes the quick action") {
                                            expect(fakeQuickActionRepository.quickActions).to(beEmpty())
                                        }
                                    }
                                }
                            }

                            it("pushes the feeds list controller if the user commits the touch") {
                                guard let vc = viewController else { fail(); return }
                                subject.previewingContext(viewControllerPreviewing, commit: vc)
                                expect(navigationController.visibleViewController) == vc
                            }

                            context("when the feeds promise succeeds") {
                                let feeds = [
                                    Feed(title: "a", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
                                    Feed(title: "b", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                                ]

                                beforeEach {
                                    feedRepository.feedsPromises.last?.resolve(.success(feeds))
                                }

                                it("sets the list of feeds") {
                                    if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                        expect(feedsList.feeds.count) == feeds.count
                                        let feed = feeds[0]
                                        feedsList.tapFeed?(feed)
                                        expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                        expect(fakeQuickActionRepository.quickActions.count) == 1
                                        if let quickAction = fakeQuickActionRepository.quickActions.first {
                                            expect(quickAction.localizedTitle) == feed.title
                                            expect(quickAction.type) == "com.rachelbrindle.rssclient.viewfeed"
                                            expect(quickAction.userInfo?["feed"] as? String) == feed.title
                                        }
                                    }
                                }
                            }
                        }

                        it("has one edit action, which deletes the quick action when selected") {
                            let indexPath = IndexPath(row: 0, section: sectionNumber)

                            let editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAt: indexPath)
                            expect(editActions?.count) == 1

                            if let action = editActions?.first {
                                expect(action.title) == "Delete"
                                action.handler?(action, indexPath)

                                expect(fakeQuickActionRepository.quickActions).to(beEmpty())
                            }
                        }
                    }


                    describe("the cell to add a new quick action") {
                        let indexPath = IndexPath(row: 1, section: sectionNumber)

                        beforeEach {
                            subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("makes a request to the data use case for feeds") {
                            expect(feedRepository.feedsPromises.count) == 1
                        }

                        it("displays a list of feeds cell") {
                            expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedsListController.self))

                            if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                expect(feedsList.navigationItem.title) == "Add a new Quick Action"
                            }
                        }

                        context("when the feeds promise succeeds") {
                            beforeEach {
                                feedRepository.feedsPromises.last?.resolve(.success(feeds))
                            }

                            it("should bring up a dialog to change the feed when one of the existing quick action cells is tapped") {
                                expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedsListController.self))

                                if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                    expect(feedsList.feeds) == [feedB]
                                    let feed = feeds[1]
                                    feedsList.tapFeed?(feed)
                                    expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                    expect(fakeQuickActionRepository.quickActions.count) == 2
                                    if let quickAction = fakeQuickActionRepository.quickActions.last {
                                        expect(quickAction.localizedTitle) == feed.title
                                        expect(quickAction.type) == "com.rachelbrindle.rssclient.viewfeed"
                                        expect(quickAction.userInfo?["feed"] as? String) == feed.title
                                    }
                                }
                            }
                        }

                        context("when the feeds promise fails") { // TODO: implement!

                        }

                        it("should not have any edit actions") {
                            let editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAt: indexPath)
                            expect(editActions).to(beNil())
                        }
                    }

                }

                context("when there are three existing quick actions") {
                    let firstShortcut = UIApplicationShortcutItem(type: "a", localizedTitle: "a")
                    let secondShortcut = UIApplicationShortcutItem(type: "b", localizedTitle: "b")
                    let thirdShortcut = UIApplicationShortcutItem(type: "c", localizedTitle: "c")

                    let feedA = Feed(title: "a", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feedB = Feed(title: "b", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feedC = Feed(title: "c", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                    let feedD = Feed(title: "d", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)

                    let feeds = [feedA, feedB, feedC, feedD]

                    beforeEach {
                        fakeQuickActionRepository.quickActions = [firstShortcut, secondShortcut, thirdShortcut]

                        subject.tableView.reloadData()
                    }

                    it("should only have cells for the existing feeds") {
                        expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == 3

                        let firstIndexPath = IndexPath(row: 0, section: sectionNumber)
                        let firstCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: firstIndexPath)
                        expect(firstCell?.textLabel?.text) == "a"

                        let secondIndexPath = IndexPath(row: 1, section: sectionNumber)
                        let secondCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: secondIndexPath)
                        expect(secondCell?.textLabel?.text) == "b"

                        let thirdIndexPath = IndexPath(row: 2, section: sectionNumber)
                        let thirdCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAt: thirdIndexPath)
                        expect(thirdCell?.textLabel?.text) == "c"
                    }

                    describe("when one of the existing quick action cells is tapped") {
                        let indexPath = IndexPath(row: 0, section: sectionNumber)

                        beforeEach {
                            subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("displays a list of feeds to change to") {
                            expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedsListController.self))

                            if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                expect(feedsList.navigationItem.title) == feedA.title
                                expect(feedsList.feeds) == []
                            }
                        }

                        it("makes a request for the list of feeds") {
                            expect(feedRepository.feedsPromises.count) == 1
                        }

                        context("when the feeds promise succeeds") {
                            beforeEach {
                                feedRepository.feedsPromises.last?.resolve(.success(feeds))
                            }

                            it("should bring up a dialog to change the feed") {
                                expect(navigationController.visibleViewController).to(beAnInstanceOf(FeedsListController.self))

                                if let feedsList = navigationController.visibleViewController as? FeedsListController {
                                    expect(feedsList.navigationItem.title) == feedA.title
                                    expect(feedsList.feeds) == [feedD]
                                    let feed = feeds[3]
                                    feedsList.tapFeed?(feed)
                                    expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                    expect(fakeQuickActionRepository.quickActions.count) == 3
                                    if let quickAction = fakeQuickActionRepository.quickActions.first {
                                        expect(quickAction.localizedTitle) == feed.title
                                        expect(quickAction.type) == "com.rachelbrindle.rssclient.viewfeed"
                                        expect(quickAction.userInfo?["feed"] as? String) == feed.title
                                    }
                                }
                            }
                        }

                        context("when the feeds promise fails") { // TODO: implement!

                        }
                    }

                    it("each has one edit action, which deletes the quick action when selected") {
                        let indexPath = IndexPath(row: 0, section: sectionNumber)
                        
                        let editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAt: indexPath)
                        expect(editActions?.count) == 1
                        
                        if let action = editActions?.first {
                            expect(action.title) == "Delete"
                            action.handler?(action, indexPath)
                            
                            expect(fakeQuickActionRepository.quickActions) == [secondShortcut, thirdShortcut]
                        }
                    }
                }
            }

            describe("the other section") {
                let sectionNumber = 2

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.unavailable
                }

                it("is titled 'Other'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Other"
                }

                it("has two cell") {
                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == 2
                }

                describe("the first cell") {
                    var cell: SwitchTableViewCell! = nil
                    let indexPath = IndexPath(row: 0, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? SwitchTableViewCell
                    }

                    it("is configured with the theme repository") {
                        expect(cell.themeRepository) == themeRepository
                    }

                    it("is titled 'Show Estimated Reading Times'") {
                        expect(cell.textLabel?.text) == "Show Estimated Reading Times"
                    }

                    describe("tapping the switch on the cell") {
                        beforeEach {
                            cell.theSwitch.isOn = false
                            cell.onTapSwitch?(cell.theSwitch)
                        }

                        it("does not yet change the settings repository") {
                            expect(settingsRepository.showEstimatedReadingLabel) == true
                        }

                        itBehavesLike("a changed setting") {
                            let op = BlockOperation {
                                expect(settingsRepository.showEstimatedReadingLabel) == false
                            }
                            return ["saveToUserDefaults": op]
                        }
                    }

                    it("does not respond to 3d touch") {
                        let viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                        let rect = subject.tableView.rectForRow(at: indexPath)
                        let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                        let viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        expect(viewController).to(beNil())
                    }
                }

                describe("the second cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = IndexPath(row: 1, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                    }

                    it("is configured with the theme repository") {
                        expect(cell.themeRepository) == themeRepository
                    }

                    it("is titled 'Export OPML'") {
                        expect(cell.textLabel?.text) == "Export OPML"
                    }

                    describe("tapping it") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("asks for the latest opml to be written to disk") {
                            expect(opmlService.didReceiveWriteOPML) == true
                        }

                        describe("if the opml service succeeds") {
                            let url = URL(fileURLWithPath: "")
                            beforeEach {
                                opmlService.writeOPMLPromises.last?.resolve(.success(url))
                            }

                            it("brings up a share sheet with the opml text as the content") {
                                expect(navigationController.visibleViewController).to(beAnInstanceOf(UIActivityViewController.self))
                                if let shareSheet = navigationController.visibleViewController as? UIActivityViewController {
                                    expect(shareSheet.activityItems as? [URL]) == [url]
                                }
                            }
                        }

                        describe("if the opml service fails") {
                            beforeEach {
                                opmlService.writeOPMLPromises.last?.resolve(.failure(.unknown))
                            }

                            it("notifies the user of the failure") {
                                expect(navigationController.visibleViewController).to(beAnInstanceOf(UIAlertController.self))
                                if let alert = navigationController.visibleViewController as? UIAlertController {
                                    expect(alert.title) == "Error Exporting OPML"
                                    expect(alert.message) == "Please Try Again"
                                    expect(alert.actions.count) == 1
                                    if let action = alert.actions.first {
                                        expect(action.title) == "Ok"
                                        expect(action.style) == UIAlertActionStyle.default

                                        action.handler?(action)
                                        expect(navigationController.visibleViewController) == subject
                                    }
                                }
                            }
                        }
                    }

                    it("does not respond to 3d touch") {
                        let viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                        let rect = subject.tableView.rectForRow(at: indexPath)
                        let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                        let viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        expect(viewController).to(beNil())
                    }
                }
            }

            describe("the credits section") {
                let sectionNumber = 3

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.unavailable
                }

                it("is titled 'Credits'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Credits"
                }

                let values: [(String, String, URL)] = [
                    ("Rachel Brindle", "Developer", URL(string: "https://twitter.com/younata")!),
                ]

                it("has \(values.count + 2) cells") {
                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == (values.count + 2)
                }

                sharedExamples("a credits cell") { (sharedContext: @escaping SharedExampleContext) in
                    var cell: TableViewCell!
                    var indexPath: IndexPath!
                    var title: String!
                    var detail: String!

                    beforeEach {
                        cell = sharedContext()["cell"] as? TableViewCell
                        indexPath = sharedContext()["indexPath"] as? IndexPath
                        title = sharedContext()["title"] as? String
                        detail = sharedContext()["detail"] as? String
                    }

                    it("is configured with the theme repository") {
                        expect(cell.themeRepository) == themeRepository
                    }

                    it("has the developer's or library's name as the text") {
                        expect(cell.textLabel?.text) == title
                    }

                    it("has either 'developer' as the detail") {
                        expect(cell.detailTextLabel?.text) == detail
                    }

                    describe("tapping it") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("should show an SFSafariViewController pointing at their url") {
                            expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                        }
                    }

                    describe("3d touching the cell") {
                        var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                        var viewController: UIViewController? = nil

                        beforeEach {
                            subject.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
                            viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                            let rect = subject.tableView.rectForRow(at: indexPath)
                            let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                            viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        }

                        it("returns an SFSafariViewController") {
                            expect(viewController).to(beAnInstanceOf(SFSafariViewController.self))
                        }

                        it("has no preview actions") {
                            expect(viewController?.previewActionItems.count) == 0
                        }

                        it("pushes the login controller if the user commits the touch") {
                            guard let vc = viewController else { fail(); return }
                            subject.previewingContext(viewControllerPreviewing, commit: vc)
                            expect(navigationController.visibleViewController) == vc
                        }
                    }
                }

                for index in 0..<values.count {
                    describe("the \(index)th cell") {
                        itBehavesLike("a credits cell") {
                            let indexPath = IndexPath(row: index, section: sectionNumber)
                            let cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath)
                            let value = values[index]
                            return [
                                "cell": cell,
                                "indexPath": indexPath,
                                "title": value.0,
                                "detail": value.1,
                                "url": value.2
                            ]
                        }
                    }
                }

                describe("the libraries cell") {
                    var cell: TableViewCell!
                    let indexPath = IndexPath(row: values.count, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                    }

                    it("is configured with the theme repository") {
                        expect(cell.themeRepository) == themeRepository
                    }

                    it("has the developer's or library's name as the text") {
                        expect(cell.textLabel?.text) == "Libraries"
                    }

                    it("has no detail") {
                        expect(cell.detailTextLabel?.text) == ""
                    }

                    describe("tapping it") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("should show a DocumentationViewController with the .libraries documentation") {
                            expect(navigationController.visibleViewController).to(beAnInstanceOf(DocumentationViewController.self))

                            if let documentationViewController = navigationController.visibleViewController as? DocumentationViewController {
                                expect(documentationViewController.documentation) == Documentation.libraries
                            }
                        }
                    }

                    describe("3d touching the cell") {
                        var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                        var viewController: UIViewController? = nil

                        beforeEach {
                            subject.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
                            viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                            let rect = subject.tableView.rectForRow(at: indexPath)
                            let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                            viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        }

                        it("returns a DocumentationViewController") {
                            expect(viewController).to(beAnInstanceOf(DocumentationViewController.self))
                            if let documentationViewController = viewController as? DocumentationViewController {
                                expect(documentationViewController.documentation) == Documentation.libraries
                            }
                        }

                        it("has no preview actions") {
                            expect(viewController?.previewActionItems.count) == 0
                        }

                        it("pushes the login controller if the user commits the touch") {
                            guard let vc = viewController else { fail(); return }
                            subject.previewingContext(viewControllerPreviewing, commit: vc)
                            expect(navigationController.visibleViewController) == vc
                        }
                    }
                }

                describe("the icons cell") {
                    var cell: TableViewCell!
                    let indexPath = IndexPath(row: values.count + 1, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                    }

                    it("is configured with the theme repository") {
                        expect(cell.themeRepository) == themeRepository
                    }

                    it("has Icons name as the text") {
                        expect(cell.textLabel?.text) == "Icons"
                    }

                    it("has no detail") {
                        expect(cell.detailTextLabel?.text) == ""
                    }

                    describe("tapping it") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("should show a DocumentationViewController with the .icons documentation") {
                            expect(navigationController.visibleViewController).to(beAnInstanceOf(DocumentationViewController.self))

                            if let documentationViewController = navigationController.visibleViewController as? DocumentationViewController {
                                expect(documentationViewController.documentation) == Documentation.icons
                            }
                        }
                    }

                    describe("3d touching the cell") {
                        var viewControllerPreviewing: FakeUIViewControllerPreviewing! = nil
                        var viewController: UIViewController? = nil

                        beforeEach {
                            subject.tableView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
                            viewControllerPreviewing = FakeUIViewControllerPreviewing(sourceView: subject.tableView, sourceRect: CGRect.zero, delegate: subject)

                            let rect = subject.tableView.rectForRow(at: indexPath)
                            let point = CGPoint(x: rect.origin.x + rect.size.width / 2.0, y: rect.origin.y + rect.size.height / 2.0)
                            viewController = subject.previewingContext(viewControllerPreviewing, viewControllerForLocation: point)
                        }

                        it("returns a DocumentationViewController") {
                            expect(viewController).to(beAnInstanceOf(DocumentationViewController.self))
                            if let documentationViewController = viewController as? DocumentationViewController {
                                expect(documentationViewController.documentation) == Documentation.icons
                            }
                        }

                        it("has no preview actions") {
                            expect(viewController?.previewActionItems.count) == 0
                        }

                        it("pushes the login controller if the user commits the touch") {
                            guard let vc = viewController else { fail(); return }
                            subject.previewingContext(viewControllerPreviewing, commit: vc)
                            expect(navigationController.visibleViewController) == vc
                        }
                    }
                }
            }
        }
    }
}

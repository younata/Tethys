import Quick
import Nimble
import rNews
import rNewsKit
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
            injector.bind(kind: ThemeRepository.self, toInstance: themeRepository)

            settingsRepository = SettingsRepository(userDefaults: nil)
            injector.bind(kind: SettingsRepository.self, toInstance: settingsRepository)

            fakeQuickActionRepository = FakeQuickActionRepository()
            injector.bind(kind: QuickActionRepository.self, toInstance: fakeQuickActionRepository)

            feedRepository = FakeDatabaseUseCase()
            injector.bind(kind: DatabaseUseCase.self, toInstance: feedRepository)

            accountRepository = FakeAccountRepository()
            accountRepository.loggedInReturns(nil)
            injector.bind(kind: AccountRepository.self, toInstance: accountRepository)
            let mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            injector.bind(string: kMainQueue, toInstance: mainQueue)

            opmlService = FakeOPMLService()
            injector.bind(kind: OPMLService.self, toInstance: opmlService)

            subject = injector.create(kind: SettingsViewController.self)!

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should restyle the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
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
                context("when .Default is the current theme") {
                    beforeEach {
                        themeRepository.theme = .default
                    }

                    it("lists every other theme but .Default") {
                        let keyCommands = subject.keyCommands
                        expect(keyCommands).toNot(beNil())
                        guard let commands = keyCommands else {
                            return
                        }

                        let expectedCommands = [
                            UIKeyCommand(input: "2", modifierFlags: .command, action: Selector("")),
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

                context("when .Dark is the current theme") {
                    beforeEach {
                        themeRepository.theme = .dark
                    }

                    it("lists every other theme but .Dark") {
                        let keyCommands = subject.keyCommands
                        expect(keyCommands).toNot(beNil())
                        guard let commands = keyCommands else {
                            return
                        }

                        let expectedCommands = [
                            UIKeyCommand(input: "1", modifierFlags: .command, action: Selector("")),
                        ]
                        let expectedDiscoverabilityTitles = [
                            "Change Theme to 'Default'",
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
                        UIKeyCommand(input: "s", modifierFlags: .command, action: Selector("")),
                        UIKeyCommand(input: "w", modifierFlags: .command, action: Selector("")),
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

            it("has 7 sections if force touch is available") {
                subject.traitCollection.forceTouchCapability = UIForceTouchCapability.available
                subject.tableView.reloadData()
                expect(subject.tableView.numberOfSections) == 7
            }

            it("has 6 sections if force touch is not available") {
                subject.traitCollection.forceTouchCapability = UIForceTouchCapability.unavailable
                subject.tableView.reloadData()
                expect(subject.tableView.numberOfSections) == 6
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
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as! TableViewCell
                    }

                    it("is titled 'Default'") {
                        expect(cell.textLabel?.text) == "Default"
                    }

                    it("has its theme repository set") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    it("is selected") {
                        expect(cell.isSelected) == true
                    }

                    it("has no edit actions") {
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAt: indexPath)).to(beNil())
                    }
                }

                describe("the second cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = IndexPath(row: 1, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as! TableViewCell
                    }

                    it("is titled 'Dark'") {
                        expect(cell.textLabel?.text) == "Dark"
                    }

                    it("is selected if it's the current theme") { // which it is not
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

                        describe("it previews the change") {
                            it("by restyling the navigation bar") {
                                expect(subject.navigationController?.navigationBar.barStyle) == UIBarStyle.black
                            }

                            it("by changing the background color of the tableView") {
                                expect(subject.tableView.backgroundColor) == UIColor.black
                            }

                            it("by changing the background color of the view") {
                                expect(subject.view.backgroundColor) == UIColor.black
                            }
                        }
                        
                        itBehavesLike("a changed setting") {
                            let op = BlockOperation {
                                expect(themeRepository.theme) == ThemeRepository.Theme.dark
                            }
                            return ["saveToUserDefaults": op]
                        }
                    }
                }
            }

            describe("the quick actions section") {
                let sectionNumber = 1

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
                                    feedsList.tapFeed?(feed, 0)
                                    expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                    expect(fakeQuickActionRepository.quickActions.count) == 1
                                    if let quickAction = fakeQuickActionRepository.quickActions.first {
                                        expect(quickAction.localizedTitle) == feed.title
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
                                    feedsList.tapFeed?(feed, 0)
                                    expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                    expect(fakeQuickActionRepository.quickActions.count) == 1
                                    if let quickAction = fakeQuickActionRepository.quickActions.first {
                                        expect(quickAction.localizedTitle) == feed.title
                                    }
                                }
                            }
                        }

                        context("when the feeds promise fails") { // TODO: implement!

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
                                    feedsList.tapFeed?(feed, 0)
                                    expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                    expect(fakeQuickActionRepository.quickActions.count) == 2
                                    if let quickAction = fakeQuickActionRepository.quickActions.last {
                                        expect(quickAction.localizedTitle) == feed.title
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
                                    feedsList.tapFeed?(feed, 0)
                                    expect(navigationController.visibleViewController).to(beIdenticalTo(subject))
                                    expect(fakeQuickActionRepository.quickActions.count) == 3
                                    if let quickAction = fakeQuickActionRepository.quickActions.first {
                                        expect(quickAction.localizedTitle) == feed.title
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

            describe("the accounts section") {
                let sectionNumber = 1

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.unavailable
                }

                it("is titled 'Accounts'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Accounts"
                }

                it("has one cell") {
                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == 1
                }

                describe("the first cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = IndexPath(row: 0, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as! TableViewCell
                    }

                    it("is configured with the theme repository") {
                        expect(cell.themeRepository) == themeRepository
                    }

                    it("is titled 'rNews Backend'") {
                        expect(cell.textLabel?.text) == "rNews Backend"
                    }

                    it("has no text in it's detail label") {
                        expect(cell.detailTextLabel?.text).to(beNil())
                    }

                    it("has no edit actions") {
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAt: indexPath)?.count) == 0
                    }

                    describe("when logged in") {
                        beforeEach {
                            accountRepository.loggedInReturns("foo@example.com")
                            cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as! TableViewCell
                        }

                        it("shows the user's email in the detail label") {
                            expect(cell.detailTextLabel?.text) == "foo@example.com"
                        }

                        it("has 1 edit action") {
                            expect(delegate.tableView?(subject.tableView, editActionsForRowAt: indexPath)?.count) == 1
                        }

                        describe("the edit action") {
                            it("logs the user out") {
                                let editAction = delegate.tableView?(subject.tableView, editActionsForRowAt: indexPath)?.first
                                expect(editAction?.title) == "Log Out"
                                editAction?.handler(editAction, indexPath)
                                expect(accountRepository.logOutCallCount) == 1
                            }
                        }
                    }

                    describe("tapping the cell") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("navigates to a page telling the user to login to Pasiphae") {
                            expect(navigationController.topViewController).to(beAnInstanceOf(LoginViewController.self))
                            if let loginViewController = navigationController.topViewController as? LoginViewController {
                                expect(loginViewController.accountType) == Account.pasiphae
                            }
                        }
                    }
                }
            }

            describe("the advanced section") {
                let sectionNumber = 2

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.unavailable
                }

                it("is titled 'Advanced'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Advanced"
                }

                it("has one cell") {
                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == 1
                }

                describe("the first cell") {
                    var cell: SwitchTableViewCell! = nil
                    let indexPath = IndexPath(row: 0, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as! SwitchTableViewCell
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
                }
            }

            describe("the refresh style section") {
                let sectionNumber = 3

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
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as! TableViewCell
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
                }

                describe("the second cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = IndexPath(row: 1, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as! TableViewCell
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
                }
            }

            describe("the other section") {
                let sectionNumber = 4

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.unavailable
                }

                it("is titled 'Other'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Other"
                }

                it("has one cell") {
                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == 1
                }

                describe("the first cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = IndexPath(row: 0, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as! TableViewCell
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

                                        action.handler(action)
                                        expect(navigationController.visibleViewController) == subject
                                    }
                                }
                            }
                        }
                    }
                }
            }

            describe("the credits section") {
                let sectionNumber = 5

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

                it("has \(values.count) cells") {
                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)) == values.count
                }

                sharedExamples("a credits cell") { (sharedContext: @escaping SharedExampleContext) in
                    var cell: TableViewCell!
                    var indexPath: IndexPath!
                    var title: String!
                    var detail: String!

                    beforeEach {
                        cell = sharedContext()["cell"] as! TableViewCell
                        indexPath = sharedContext()["indexPath"] as! IndexPath
                        title = sharedContext()["title"] as! String
                        detail = sharedContext()["detail"] as! String
                    }

                    it("is configured with the theme repository") {
                        expect(cell.themeRepository) == themeRepository
                    }

                    it("has the developer's or library's name as the text") {
                        expect(cell.textLabel?.text) == title
                    }

                    it("has either 'developer' or 'library' title as the detail") {
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
            }
        }
    }
}

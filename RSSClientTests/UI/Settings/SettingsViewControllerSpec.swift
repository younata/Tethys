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

        beforeEach {
            let injector = Injector()

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, toInstance: themeRepository)

            settingsRepository = SettingsRepository(userDefaults: nil)
            injector.bind(SettingsRepository.self, toInstance: settingsRepository)

            fakeQuickActionRepository = FakeQuickActionRepository()
            injector.bind(QuickActionRepository.self, toInstance: fakeQuickActionRepository)

            feedRepository = FakeDatabaseUseCase()
            injector.bind(DatabaseUseCase.self, toInstance: feedRepository)

            accountRepository = FakeAccountRepository()
            accountRepository.loggedInReturns(nil)
            injector.bind(AccountRepository.self, toInstance: accountRepository)
            let mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true
            injector.bind(kMainQueue, toInstance: mainQueue)

            subject = injector.create(SettingsViewController)!

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should restyle the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
            }

            it("by changing the background color of the tableView") {
                expect(subject.tableView.backgroundColor) == UIColor.blackColor()
            }

            it("should change the background color of the view") {
                expect(subject.view.backgroundColor) == themeRepository.backgroundColor
            }
        }

        it("is titled 'Settings'") {
            expect(subject.navigationItem.title) == "Settings"
        }

        it("has a disabled save button") {
            expect(subject.navigationItem.rightBarButtonItem?.enabled) == false
        }

        describe("tapping the cancel button") {
            var rootViewController: UIViewController! = nil
            beforeEach {
                rootViewController = UIViewController()
                rootViewController.presentViewController(navigationController, animated: false, completion: nil)
                expect(rootViewController.presentedViewController).to(beIdenticalTo(navigationController))

                subject.navigationItem.leftBarButtonItem?.tap()
            }

            it("dismisses itself") {
                expect(rootViewController.presentedViewController).to(beNil())
            }
        }

        sharedExamples("a changed setting") { (sharedContext: SharedExampleContext) in
            it("should enable the save button") {
                expect(subject.navigationItem.rightBarButtonItem?.enabled) == true
            }

            describe("tapping the save button") {
                var rootViewController: UIViewController! = nil
                beforeEach {
                    rootViewController = UIViewController()
                    rootViewController.presentViewController(navigationController, animated: false, completion: nil)
                    expect(rootViewController.presentedViewController).toNot(beNil())

                    subject.navigationItem.rightBarButtonItem?.tap()
                }

                it("dismisses itself") {
                    expect(rootViewController.presentedViewController).to(beNil())
                }

                it("saves the change to the userDefaults") {
                    let op = sharedContext()["saveToUserDefaults"] as? NSOperation
                    op?.main()
                }
            }
        }

        describe("key commands") {
            it("can become first responder") {
                expect(subject.canBecomeFirstResponder()) == true
            }

            it("has (number of themes - 1) + 2 commands") {
                let keyCommands = subject.keyCommands
                expect(keyCommands?.count) == 3
            }

            describe("the first (number of themes - 1) commands") {
                context("when .Default is the current theme") {
                    beforeEach {
                        themeRepository.theme = .Default
                    }

                    it("lists every other theme but .Default") {
                        let keyCommands = subject.keyCommands
                        expect(keyCommands).toNot(beNil())
                        guard let commands = keyCommands else {
                            return
                        }

                        let expectedCommands = [
                            UIKeyCommand(input: "2", modifierFlags: .Command, action: Selector()),
                        ]
                        let expectedDiscoverabilityTitles = [
                            "Change Theme to 'Dark'",
                        ]

                        for (idx, expectedCmd) in expectedCommands.enumerate() {
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
                        themeRepository.theme = .Dark
                    }

                    it("lists every other theme but .Dark") {
                        let keyCommands = subject.keyCommands
                        expect(keyCommands).toNot(beNil())
                        guard let commands = keyCommands else {
                            return
                        }

                        let expectedCommands = [
                            UIKeyCommand(input: "1", modifierFlags: .Command, action: Selector()),
                        ]
                        let expectedDiscoverabilityTitles = [
                            "Change Theme to 'Default'",
                        ]

                        for (idx, expectedCmd) in expectedCommands.enumerate() {
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
                        UIKeyCommand(input: "s", modifierFlags: .Command, action: Selector()),
                        UIKeyCommand(input: "w", modifierFlags: .Command, action: Selector()),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Save and dismiss",
                        "Dismiss without saving",
                    ]

                    expect(commands.count) == expectedCommands.count
                    for (idx, cmd) in commands.enumerate() {
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

            it("should have 5 sections if force touch is available") {
                subject.traitCollection.forceTouchCapability = UIForceTouchCapability.Available
                subject.tableView.reloadData()
                expect(subject.tableView.numberOfSections) == 5
            }

            it("should have 4 sections if force touch is not available") {
                subject.traitCollection.forceTouchCapability = UIForceTouchCapability.Unavailable
                subject.tableView.reloadData()
                expect(subject.tableView.numberOfSections) == 4
            }

            describe("the theme section") {
                let sectionNumber = 0

                it("should be titled 'Theme'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Theme"
                }

                it("should have 2 cells") {
                    expect(subject.tableView.numberOfRowsInSection(sectionNumber)) == 2
                }

                describe("the first cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! TableViewCell
                    }

                    it("should be titled 'Default'") {
                        expect(cell.textLabel?.text) == "Default"
                    }

                    it("should have its theme repository set") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    it("should be selected") {
                        expect(cell.selected) == true
                    }

                    it("should have no edit actions") {
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)).to(beNil())
                    }
                }

                describe("the second cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = NSIndexPath(forRow: 1, inSection: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! TableViewCell
                    }

                    it("should be titled 'Dark'") {
                        expect(cell.textLabel?.text) == "Dark"
                    }

                    it("should be selected if it's the current theme") { // which it is not
                        expect(cell.selected) == false
                    }

                    it("should have its theme repository set") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    it("should have no edit actions") {
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)).to(beNil())
                    }

                    describe("when tapped") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)
                        }

                        describe("it previews the change") {
                            it("by restyling the navigation bar") {
                                expect(subject.navigationController?.navigationBar.barStyle) == UIBarStyle.Black
                            }

                            it("by changing the background color of the tableView") {
                                expect(subject.tableView.backgroundColor) == UIColor.blackColor()
                            }

                            it("by changing the background color of the view") {
                                expect(subject.view.backgroundColor) == UIColor.blackColor()
                            }
                        }
                        
                        itBehavesLike("a changed setting") {
                            let op = NSBlockOperation {
                                expect(themeRepository.theme) == ThemeRepository.Theme.Dark
                            }
                            return ["saveToUserDefaults": op]
                        }
                    }
                }
            }

            describe("the quick actions section") {
                let sectionNumber = 1

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.Available
                }

                it("should be titled 'Quick Actions'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Quick Actions"
                }

                context("when there are no existing quick actions") {
                    beforeEach {
                        fakeQuickActionRepository.quickActions = []
                        subject.tableView.reloadData()
                    }

                    it("should have a single cell, inviting the user to add a quick action") {
                        expect(subject.tableView.numberOfRowsInSection(sectionNumber)) == 1

                        let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)
                        let cell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAtIndexPath: indexPath)

                        expect(cell?.textLabel?.text) == "Add a Quick Action"
                    }

                    describe("tapping the add cell") {
                        let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                        let feeds = [
                            Feed(title: "a", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil),
                            Feed(title: "b", url: URL(string: "https://example.com")!, summary: "", tags: [], waitPeriod: 0, remainingWait: 0, articles: [], image: nil)
                        ]

                        beforeEach {
                            subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)
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
                        let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                        let editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)
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
                        expect(subject.tableView.numberOfRowsInSection(sectionNumber)) == 2
                        let firstIndexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)
                        let firstCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAtIndexPath: firstIndexPath)

                        expect(firstCell?.textLabel?.text) == "a"

                        let secondIndexPath = NSIndexPath(forRow: 1, inSection: sectionNumber)
                        let secondCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAtIndexPath: secondIndexPath)

                        expect(secondCell?.textLabel?.text) == "Add a new Quick Action"
                    }

                    describe("the cell for an existing quick action") {
                        let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                        beforeEach {
                            subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)
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

                        it("should have one edit action, which deletes the quick action when selected") {
                            let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                            let editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)
                            expect(editActions?.count) == 1

                            if let action = editActions?.first {
                                expect(action.title) == "Delete"
                                action.handler?(action, indexPath)

                                expect(fakeQuickActionRepository.quickActions).to(beEmpty())
                            }
                        }
                    }


                    describe("the cell to add a new quick action") {
                        let indexPath = NSIndexPath(forRow: 1, inSection: sectionNumber)

                        beforeEach {
                            subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)
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
                            let editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)
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
                        expect(subject.tableView.numberOfRowsInSection(sectionNumber)) == 3

                        let firstIndexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)
                        let firstCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAtIndexPath: firstIndexPath)
                        expect(firstCell?.textLabel?.text) == "a"

                        let secondIndexPath = NSIndexPath(forRow: 1, inSection: sectionNumber)
                        let secondCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAtIndexPath: secondIndexPath)
                        expect(secondCell?.textLabel?.text) == "b"

                        let thirdIndexPath = NSIndexPath(forRow: 2, inSection: sectionNumber)
                        let thirdCell = subject.tableView.dataSource?.tableView(subject.tableView, cellForRowAtIndexPath: thirdIndexPath)
                        expect(thirdCell?.textLabel?.text) == "c"
                    }

                    describe("when one of the existing quick action cells is tapped") {
                        let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                        beforeEach {
                            subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)
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

                    it("each should have one edit action, which deletes the quick action when selected") {
                        let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)
                        
                        let editActions = subject.tableView.delegate?.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)
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
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.Unavailable
                }

                it("is titled 'Accounts'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Accounts"
                }

                it("has one cell") {
                    expect(subject.tableView.numberOfRowsInSection(sectionNumber)) == 1
                }

                describe("the first cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! TableViewCell
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
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)?.count) == 0
                    }

                    describe("when logged in") {
                        beforeEach {
                            accountRepository.loggedInReturns("foo@example.com")
                            cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! TableViewCell
                        }

                        it("shows the user's email in the detail label") {
                            expect(cell.detailTextLabel?.text) == "foo@example.com"
                        }

                        it("has 1 edit action") {
                            expect(delegate.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)?.count) == 1
                        }

                        describe("the edit action") {
                            it("logs the user out") {
                                let editAction = delegate.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)?.first
                                expect(editAction?.title) == "Log Out"
                                editAction?.handler(editAction, indexPath)
                                expect(accountRepository.logOutCallCount) == 1
                            }
                        }
                    }

                    describe("tapping the cell") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)
                        }

                        it("navigates to a page telling the user to login to Pasiphae") {
                            expect(navigationController.topViewController).to(beAnInstanceOf(LoginViewController.self))
                            if let loginViewController = navigationController.topViewController as? LoginViewController {
                                expect(loginViewController.accountType) == Account.Pasiphae
                            }
                        }
                    }
                }
            }

            describe("the advanced section") {
                let sectionNumber = 2

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.Unavailable
                }

                it("is titled 'Advanced'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Advanced"
                }

                it("has one cell") {
                    expect(subject.tableView.numberOfRowsInSection(sectionNumber)) == 1
                }

                describe("the first cell") {
                    var cell: SwitchTableViewCell! = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! SwitchTableViewCell
                    }

                    it("is configured with the theme repository") {
                        expect(cell.themeRepository) == themeRepository
                    }

                    it("is titled 'Show Estimated Reading Times'") {
                        expect(cell.textLabel?.text) == "Show Estimated Reading Times"
                    }

                    describe("tapping the switch on the cell") {
                        beforeEach {
                            cell.theSwitch.on = false
                            cell.onTapSwitch?(cell.theSwitch)
                        }

                        it("does not yet change the settings repository") {
                            expect(settingsRepository.showEstimatedReadingLabel) == true
                        }

                        itBehavesLike("a changed setting") {
                            let op = NSBlockOperation {
                                expect(settingsRepository.showEstimatedReadingLabel) == false
                            }
                            return ["saveToUserDefaults": op]
                        }
                    }
                }
            }

            describe("the credits section") {
                let sectionNumber = 3

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.Unavailable
                }

                it("should be titled 'Credits'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Credits"
                }

                let values: [(String, String, URL)] = [
                    ("Rachel Brindle", "Developer", URL(string: "https://twitter.com/younata")!),
                ]

                it("should have \(values.count) cells") {
                    expect(subject.tableView.numberOfRowsInSection(sectionNumber)) == values.count
                }

                sharedExamples("a credits cell") { (sharedContext: SharedExampleContext) in
                    var cell: TableViewCell!
                    var indexPath: NSIndexPath!
                    var title: String!
                    var detail: String!

                    beforeEach {
                        cell = sharedContext()["cell"] as! TableViewCell
                        indexPath = sharedContext()["indexPath"] as! NSIndexPath
                        title = sharedContext()["title"] as! String
                        detail = sharedContext()["detail"] as! String
                    }

                    it("should be configured with the theme repository") {
                        expect(cell.themeRepository) == themeRepository
                    }

                    it("should have the proper text") {
                        expect(cell.textLabel?.text) == title
                    }

                    it("should show the proper detail text") {
                        expect(cell.detailTextLabel?.text) == detail
                    }

                    describe("tapping it") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)
                        }

                        it("should show an SFSafariViewController pointing at that url") {
                            expect(navigationController.visibleViewController).to(beAnInstanceOf(SFSafariViewController.self))
                        }
                    }
                }

                for index in 0..<values.count {
                    describe("the \(index)th cell") {
                        itBehavesLike("a credits cell") {
                            let indexPath = NSIndexPath(forRow: index, inSection: sectionNumber)
                            let cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath)
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

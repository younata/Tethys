import Quick
import Nimble
import TethysKit
import SafariServices
@testable import TethysKit
@testable import Tethys

class SettingsViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SettingsViewController!
        var navigationController: UINavigationController!
        var themeRepository: ThemeRepository!
        var settingsRepository: SettingsRepository!
        var accountService: FakeAccountService!
        var opmlService: FakeOPMLService!
        var messenger: FakeMessenger!
        var loginController: FakeLoginController!

        var rootViewController: UIViewController!

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)

            settingsRepository = SettingsRepository(userDefaults: nil)

            let mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            opmlService = FakeOPMLService()
            accountService = FakeAccountService()

            messenger = FakeMessenger()

            loginController = FakeLoginController()

            subject = SettingsViewController(
                themeRepository: themeRepository,
                settingsRepository: settingsRepository,
                opmlService: opmlService,
                mainQueue: mainQueue,
                accountService: accountService,
                messenger: messenger,
                loginController: loginController,
                documentationViewController: { documentation in documentationViewControllerFactory(documentation: documentation) }
            )

            rootViewController = UIViewController()

            navigationController = UINavigationController(rootViewController: subject)
            rootViewController.present(navigationController, animated: false, completion: nil)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should restyle the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
                expect(
                    convertFromOptionalNSAttributedStringKeyDictionary(subject.navigationController?.navigationBar.titleTextAttributes) as? [String: UIColor]
                ).to(equal([
                    convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): themeRepository.textColor
                ]))
            }

            it("by changing the background color of the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(UIColor.black))
            }

            it("should change the background color of the view") {
                expect(subject.view.backgroundColor).to(equal(themeRepository.backgroundColor))
            }
        }

        it("is titled 'Settings'") {
            expect(subject.navigationItem.title).to(equal("Settings"))
        }

        it("has a disabled save button") {
            expect(subject.navigationItem.rightBarButtonItem?.isEnabled).to(equal(false))
        }

        it("has a close button") {
            expect(subject.navigationItem.leftBarButtonItem?.title).to(equal("Close"))
            expect(subject.navigationItem.leftBarButtonItem?.isEnabled).to(equal(true))
        }

        it("makes a request for the logged in accounts") {
            expect(accountService.accountsPromises).to(haveCount(1))
        }

        sharedExamples("a changed setting") { (sharedContext: @escaping SharedExampleContext) in
            it("should enable the save button") {
                expect(subject.navigationItem.rightBarButtonItem?.isEnabled) == true
            }

            describe("tapping the save button") {
                beforeEach {
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

            describe("tapping the close button") {
                beforeEach {
                    subject.navigationItem.leftBarButtonItem?.tap()
                }

                it("dismisses itself") {
                    expect(rootViewController.presentedViewController).to(beNil())
                }

                it("does not save the change to the userDefaults") {
                    let op = sharedContext()["dismissWithoutSaving"] as? Operation
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
                            (input: "2", modifierFlags: UIKeyModifierFlags.command)
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
                            (input: "1", modifierFlags: UIKeyModifierFlags.command),
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
                        (input: "s", modifierFlags: UIKeyModifierFlags.command),
                        (input: "w", modifierFlags: UIKeyModifierFlags.command),
                    ]
                    let expectedDiscoverabilityTitles = [
                        "Save and dismiss",
                        "Close without saving",
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

            it("has 4 sections") { // until I get accounts working.
                expect(subject.tableView.numberOfSections).to(equal(4))
                // expect(subject.tableView.numberOfSections).to(equal(5))
            }

            xdescribe("the account section") {
                let sectionNumber = 0

                it("is titled 'Account'") {
                    expect(dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)).to(equal("Account"))
                }

                context("if there is no local account for this user") {
                    beforeEach {
                        accountService.accountsPromises.last?.resolve([])
                        subject.tableView.reloadData()
                    }

                    it("has a single cell") {
                        expect(subject.tableView.numberOfRows(inSection: sectionNumber)).to(equal(1))
                    }

                    describe("the cell") {
                        var cell: TableViewCell?
                        let indexPath = IndexPath(row: 0, section: sectionNumber)

                        beforeEach {
                            cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                        }

                        it("it asks the user to log in") {
                            expect(cell?.textLabel?.text).to(equal("Inoreader"))
                            expect(cell?.detailTextLabel?.text).to(equal("Add account"))
                        }

                        it("has its themeRepository set") {
                            expect(cell?.themeRepository).to(beIdenticalTo(themeRepository))
                        }

                        describe("tapping the cell") {
                            beforeEach {
                                subject.tableView.delegate?.tableView?(subject.tableView, didSelectRowAt: indexPath)
                            }

                            it("asks the login controller to begin the login process") {
                                expect(loginController.beginPromises).to(haveCount(1))
                            }

                            describe("when the login succeeds") {
                                beforeEach {
                                    loginController.beginPromises.last?.resolve(.success(Account(
                                        kind: .inoreader,
                                        username: "username",
                                        id: "id"
                                    )))
                                }

                                it("shows the account in the table") {
                                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)).to(equal(2))
                                    cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                                    expect(cell?.textLabel?.text).to(equal("Inoreader"))
                                    expect(cell?.detailTextLabel?.text).to(equal("username"))
                                }

                                it("still shows the add account in the table") {
                                    let addIndexPath = IndexPath(row: 1, section: sectionNumber)
                                    let addCell = dataSource.tableView(subject.tableView, cellForRowAt: addIndexPath) as? TableViewCell
                                    expect(addCell?.textLabel?.text).to(equal("Inoreader"))
                                    expect(addCell?.detailTextLabel?.text).to(equal("Add account"))
                                }
                            }

                            describe("when the login fails") {
                                context("because something nefarious was going on") {
                                    beforeEach {
                                        loginController.beginPromises.last?.resolve(.failure(.network(
                                            URL(string: "https://www.inoreader.com/oauth2/auth")!,
                                            .badResponse
                                        )))
                                    }

                                    it("tells the user something was up") {
                                        expect(messenger.warningCalls).to(haveCount(1))
                                        guard let call = messenger.warningCalls.last else { return }

                                        expect(call.title).to(equal("Unable to Authenticate"))
                                        expect(call.message).to(equal("Please try again"))
                                    }
                                }

                                context("because the user cancelled") {
                                    beforeEach {
                                        loginController.beginPromises.last?.resolve(.failure(.network(
                                            URL(string: "https://www.inoreader.com/oauth2/auth")!,
                                            .cancelled
                                        )))
                                    }

                                    it("does not show an alert") {
                                        expect(messenger.warningCalls).to(beEmpty())
                                    }

                                    it("does not alter the table") {
                                        expect(subject.tableView.numberOfRows(inSection: sectionNumber)).to(equal(1))
                                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                                        expect(cell?.textLabel?.text).to(equal("Inoreader"))
                                        expect(cell?.detailTextLabel?.text).to(equal("Add account"))
                                    }
                                }

                                context("for any other reason") {
                                    beforeEach {
                                        loginController.beginPromises.last?.resolve(.failure(.network(
                                            URL(string: "https://www.inoreader.com/oauth2/auth")!,
                                            .unknown
                                        )))
                                    }

                                    it("tells the user there was an error") {
                                        expect(messenger.warningCalls).to(haveCount(1))
                                        guard let call = messenger.warningCalls.last else { return }

                                        expect(call.title).to(equal("Unable to Authenticate"))
                                        expect(call.message).to(equal("Please try again"))
                                    }

                                    it("does not alter the table") {
                                        expect(subject.tableView.numberOfRows(inSection: sectionNumber)).to(equal(1))
                                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                                        expect(cell?.textLabel?.text).to(equal("Inoreader"))
                                        expect(cell?.detailTextLabel?.text).to(equal("Add account"))
                                    }
                                }
                            }
                        }
                    }
                }

                context("if there is an account for this user") {
                    beforeEach {
                        accountService.accountsPromises.last?.resolve([
                            .success(Account(
                                kind: .inoreader,
                                username: "username",
                                id: "id"
                            ))
                        ])
                        subject.tableView.reloadData()
                    }

                    it("has a two cells") {
                        expect(subject.tableView.numberOfRows(inSection: sectionNumber)).to(equal(2))
                    }

                    it("the first cell states the account type and username") {
                        let indexPath = IndexPath(row: 0, section: sectionNumber)
                        let cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                        expect(cell?.textLabel?.text).to(equal("Inoreader"))
                        expect(cell?.detailTextLabel?.text).to(equal("username"))
                    }

                    it("the second cell shows the add account in the table") {
                        let addIndexPath = IndexPath(row: 1, section: sectionNumber)
                        let addCell = dataSource.tableView(subject.tableView, cellForRowAt: addIndexPath) as? TableViewCell
                        expect(addCell?.textLabel?.text).to(equal("Inoreader"))
                        expect(addCell?.detailTextLabel?.text).to(equal("Add account"))
                    }
                }
            }

            describe("the theme section") {
                let sectionNumber = 0 // 1

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
                            let saveOperation = BlockOperation {
                                expect(themeRepository.theme).to(equal(ThemeRepository.Theme.light))
                            }
                            let dismissOperation = BlockOperation {
                                expect(themeRepository.theme).to(equal(ThemeRepository.Theme.dark))
                            }
                            return ["saveToUserDefaults": saveOperation, "dismissWithoutSaving": dismissOperation]
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
                        expect(subject.tableView.indexPathsForSelectedRows).to(contain(indexPath))
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
                let sectionNumber = 1 //2

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

                    describe("when tapped") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }
                        itBehavesLike("a changed setting") {
                            let saveOperation = BlockOperation {
                                expect(settingsRepository.refreshControl).to(equal(RefreshControlStyle.breakout))
                            }
                            let dismissOperation = BlockOperation {
                                expect(settingsRepository.refreshControl).to(equal(RefreshControlStyle.spinner))
                            }
                            return ["saveToUserDefaults": saveOperation, "dismissWithoutSaving": dismissOperation]
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

            describe("the other section") {
                let sectionNumber = 2 // 3

                beforeEach {
                    subject.traitCollection.forceTouchCapability = UIForceTouchCapability.unavailable
                }

                it("is titled 'Other'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title) == "Other"
                }

                it("has three cells") {
                    expect(subject.tableView.numberOfRows(inSection: sectionNumber)).to(equal(3))
                }

                describe("the estimated reading times cell") {
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
                            expect(settingsRepository.showEstimatedReadingLabel).to(equal(true))
                        }

                        itBehavesLike("a changed setting") {
                            let saveOperation = BlockOperation {
                                expect(settingsRepository.showEstimatedReadingLabel).to(equal(false))
                            }
                            let dismissOperation = BlockOperation {
                                expect(settingsRepository.showEstimatedReadingLabel).to(equal(true))
                            }
                            return ["saveToUserDefaults": saveOperation, "dismissWithoutSaving": dismissOperation]
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

                describe("the export cell") {
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
                                        expect(action.style) == UIAlertAction.Style.default

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

                describe("the version cell") {
                    var cell: TableViewCell!
                    let indexPath = IndexPath(row: 2, section: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAt: indexPath) as? TableViewCell
                    }

                    it("is configured with the theme repository") {
                        expect(cell.themeRepository).to(equal(themeRepository))
                    }

                    it("has 'version'' name as the text") {
                        expect(cell.textLabel?.text).to(equal("Version"))
                    }

                    it("has the git version as the detail text") {
                        let gitVersion = Bundle.main.infoDictionary?["CurrentGitVersion"] as? String
                        expect(cell.detailTextLabel?.text).to(equal(gitVersion))
                    }

                    describe("tapping it") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAt: indexPath)
                        }

                        it("does nothing") {
                            expect(navigationController.visibleViewController).to(be(subject))
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

                        it("does nothing") {
                            expect(viewController).to(beNil())
                        }
                    }
                }
            }

            describe("the credits section") {
                let sectionNumber = 3// 4

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
                    // people getting credit
                    // libraries
                    // icons
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

                        it("shows a DocumentationViewController with the .icons documentation") {
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

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSAttributedStringKeyDictionary(_ input: [NSAttributedString.Key: Any]?) -> [String: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

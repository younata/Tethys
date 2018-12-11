import Quick
import Nimble
import Tethys
import TethysKit
import SafariServices

class SettingsViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SettingsViewController! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: ThemeRepository! = nil
        var settingsRepository: SettingsRepository! = nil
        var opmlService: FakeOPMLService! = nil

        beforeEach {
            themeRepository = ThemeRepository(userDefaults: nil)

            settingsRepository = SettingsRepository(userDefaults: nil)

            let mainQueue = FakeOperationQueue()
            mainQueue.runSynchronously = true

            opmlService = FakeOPMLService()

            subject = SettingsViewController(
                themeRepository: themeRepository,
                settingsRepository: settingsRepository,
                opmlService: opmlService,
                mainQueue: mainQueue,
                documentationViewController: { documentation in documentationViewControllerFactory(documentation: documentation) }
            )

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .dark
            }

            it("should restyle the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle) == themeRepository.barStyle
                expect(
                    convertFromOptionalNSAttributedStringKeyDictionary(subject.navigationController?.navigationBar.titleTextAttributes) as? [String: UIColor]
                ).to(equal([
                    convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor): themeRepository.textColor
                ]))
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

            it("has 5 sections") {
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

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSAttributedStringKeyDictionary(_ input: [NSAttributedString.Key: Any]?) -> [String: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

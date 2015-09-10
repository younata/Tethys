import Quick
import Nimble
import rNews
import Ra
import SafariServices

private class FakeUrlOpener: UrlOpener {

    private var url: NSURL? = nil
    private func openURL(url: NSURL) -> Bool {
        self.url = url
        return true
    }

    init() {}
}

class SettingsViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SettingsViewController! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: ThemeRepository! = nil
        var settingsRepository: SettingsRepository! = nil
        var urlOpener: FakeUrlOpener! = nil

        beforeEach {
            let injector = Injector()

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, to: themeRepository)

            settingsRepository = SettingsRepository(userDefaults: nil)
            injector.bind(SettingsRepository.self, to: settingsRepository)

            urlOpener = FakeUrlOpener()
            injector.bind(UrlOpener.self, to: urlOpener)

            subject = injector.create(SettingsViewController.self) as! SettingsViewController

            navigationController = UINavigationController(rootViewController: subject)

            expect(subject.view).toNot(beNil())
        }

        describe("changing the theme") {
            beforeEach {
                themeRepository.theme = .Dark
            }

            it("should restyle the navigation bar") {
                expect(subject.navigationController?.navigationBar.barStyle).to(equal(themeRepository.barStyle))
            }

            it("by changing the background color of the tableView") {
                expect(subject.tableView.backgroundColor).to(equal(UIColor.blackColor()))
            }

            it("should change the background color of the view") {
                expect(subject.view.backgroundColor).to(equal(themeRepository.backgroundColor))
            }
        }

        it("is titled 'Settings'") {
            expect(subject.navigationItem.title).to(equal("Settings"))
        }

        it("has a disabled save button") {
            expect(subject.navigationItem.rightBarButtonItem?.enabled).to(beFalsy())
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
                expect(subject.navigationItem.rightBarButtonItem?.enabled).to(beTruthy())
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

        describe("the tableView") {
            var delegate: UITableViewDelegate! = nil
            var dataSource: UITableViewDataSource! = nil

            beforeEach {
                delegate = subject.tableView.delegate
                dataSource = subject.tableView.dataSource
            }

            it("should have 3 sections") {
                expect(subject.tableView.numberOfSections).to(equal(3))
            }

            describe("the theme section") {
                let sectionNumber = 0

                it("should be titled 'Theme'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title).to(equal("Theme"))
                }

                it("should have 2 cells") {
                    expect(subject.tableView.numberOfRowsInSection(sectionNumber)).to(equal(2))
                }

                describe("the first cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! TableViewCell
                    }

                    it("should be titled 'Default'") {
                        expect(cell.textLabel?.text).to(equal("Default"))
                    }

                    it("should have its theme repository set") {
                        expect(cell.themeRepository).to(beIdenticalTo(themeRepository))
                    }

                    it("should be selected") {
                        expect(cell.selected).to(beTruthy())
                    }

                    it("should have no edit actions") {
                        expect(delegate.tableView?(subject.tableView, editActionsForRowAtIndexPath: indexPath)).to(beNil())
                    }

                    // not selectable because it's currently selected.
                }

                describe("the second cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = NSIndexPath(forRow: 1, inSection: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! TableViewCell
                    }

                    it("should be titled 'Dark'") {
                        expect(cell.textLabel?.text).to(equal("Dark"))
                    }

                    it("should be selected if it's the current theme") { // which it is not
                        expect(cell.selected).to(beFalsy())
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
                                expect(subject.navigationController?.navigationBar.barStyle).to(equal(UIBarStyle.Black))
                            }

                            it("by changing the background color of the tableView") {
                                expect(subject.tableView.backgroundColor).to(equal(UIColor.blackColor()))
                            }

                            it("by changing the background color of the view") {
                                expect(subject.view.backgroundColor).to(equal(UIColor.blackColor()))
                            }
                        }
                        
                        itBehavesLike("a changed setting") {
                            let op = NSBlockOperation {
                                expect(themeRepository.theme).to(equal(ThemeRepository.Theme.Dark))
                            }
                            return ["saveToUserDefaults": op]
                        }
                    }
                }
            }

            describe("the advanced section") {
                let sectionNumber = 1

                it("should be titled 'Advanced'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title).to(equal("Advanced"))
                }

                it("should have a single cell") {
                    expect(subject.tableView.numberOfRowsInSection(sectionNumber)).to(equal(1))
                }

                describe("the first cell") {
                    var cell: SwitchTableViewCell! = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! SwitchTableViewCell
                    }

                    it("should be configured with the theme repository") {
                        expect(cell.themeRepository).to(equal(themeRepository))
                    }

                    it("should be titled 'Enable Query Feeds'") {
                        expect(cell.textLabel?.text).to(equal("Enable Query Feeds"))
                    }

                    describe("tapping the switch on the cell") {
                        beforeEach {
                            cell.theSwitch.on = true
                            cell.onTapSwitch(cell.theSwitch)
                        }

                        it("should not yet change the settings repository") {
                            expect(settingsRepository.queryFeedsEnabled).to(beFalsy())
                        }

                        itBehavesLike("a changed setting") {
                            let op = NSBlockOperation {
                                expect(settingsRepository.queryFeedsEnabled).to(beTruthy())
                            }
                            return ["saveToUserDefaults": op]
                        }
                    }

                    describe("tapping the cell") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)
                        }

                        it("should navigate to a leaf page describing what query feeds are and why they're awesome") {
                            expect(navigationController.topViewController).to(beAnInstanceOf(DocumentationViewController.self))
                            if let documentation = navigationController.topViewController as? DocumentationViewController {
                                expect(documentation.document).to(equal(DocumentationViewController.Document.QueryFeed))
                            }
                        }
                    }
                }
            }

            describe("the credits section") {
                let sectionNumber = 2

                it("should be titled 'Credits'") {
                    let title = dataSource.tableView?(subject.tableView, titleForHeaderInSection: sectionNumber)
                    expect(title).to(equal("Credits"))
                }

                it("should have a single cell") {
                    expect(subject.tableView.numberOfRowsInSection(sectionNumber)).to(equal(1))
                }

                describe("the first cell") {
                    var cell: TableViewCell! = nil
                    let indexPath = NSIndexPath(forRow: 0, inSection: sectionNumber)

                    beforeEach {
                        cell = dataSource.tableView(subject.tableView, cellForRowAtIndexPath: indexPath) as! TableViewCell
                    }

                    it("should be configured with the theme repository") {
                        expect(cell.themeRepository).to(equal(themeRepository))
                    }

                    it("should have my name") {
                        expect(cell.textLabel?.text).to(equal("Rachel Brindle"))
                    }

                    it("should say that I'm the developer") {
                        expect(cell.detailTextLabel?.text).to(equal("Developer"))
                    }

                    describe("tapping it") {
                        beforeEach {
                            delegate.tableView?(subject.tableView, didSelectRowAtIndexPath: indexPath)
                        }

                        if #available(iOS 9.0, *) {
                            context("on iOS 9") {
                                it("should present an SFSafariViewController pointing at that url") {
                                    expect(subject.presentedViewController).to(beAnInstanceOf(SFSafariViewController.self))
                                }
                            }
                        } else {
                            context("on iOS 8") {
                                it("should navigate outside the app to my twitter handle") {
                                    expect(urlOpener.url).to(equal(NSURL(string: "https://twitter.com/younata")))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

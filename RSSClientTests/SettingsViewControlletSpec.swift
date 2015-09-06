import Quick
import Nimble
import rNews
import Ra

class SettingsViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SettingsViewController! = nil
        var navigationController: UINavigationController! = nil
        var themeRepository: ThemeRepository! = nil

        beforeEach {
            let injector = Injector()

            themeRepository = FakeThemeRepository()
            injector.bind(ThemeRepository.self, to: themeRepository)

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

                    subject.navigationItem.leftBarButtonItem?.tap()
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
            let sectionNumber = 0
            var delegate: UITableViewDelegate! = nil
            var dataSource: UITableViewDataSource! = nil

            beforeEach {
                delegate = subject.tableView.delegate
                dataSource = subject.tableView.dataSource
            }

            it("should have a section") {
                expect(subject.tableView.numberOfSections).to(equal(1))
            }

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
    }
}

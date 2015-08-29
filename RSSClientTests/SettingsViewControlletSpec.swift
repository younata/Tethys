import Quick
import Nimble
import rNews

class SettingsViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: SettingsViewController! = nil
        var navigationController: UINavigationController! = nil
        var userDefaults: NSUserDefaults! = nil

        beforeEach {
            subject = SettingsViewController()

            userDefaults = NSUserDefaults()

            navigationController = UINavigationController(rootViewController: subject)

            subject.view.layoutIfNeeded()
        }

        it("is titled 'Settings'") {
            expect(subject.navigationItem.title).to(equal("Settings"))
        }

        it("has a disabled save button") {
            expect(subject.navigationItem.rightBarButtonItem?.enabled).to(beFalsy())
        }

        describe("tapping the cancel button") {
            var rootViewController: UIViewController! = nil
            var window: UIWindow? = nil
            beforeEach {
                window = UIWindow()
                window?.makeKeyAndVisible()
                rootViewController = UIViewController()
                window?.rootViewController = rootViewController
                rootViewController.presentViewController(navigationController, animated: false, completion: nil)
                NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.01))
                expect(rootViewController.presentedViewController).to(beIdenticalTo(navigationController))

                subject.navigationItem.leftBarButtonItem?.tap()
                NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 2))
            }

            afterEach {
                window?.hidden = true
                window?.rootViewController = nil
                window = nil
            }

            it("dismisses itself") {
                expect(rootViewController.presentedViewController).toEventually(beNil())
            }
        }

        sharedExamples("a changed setting") { (sharedContext: SharedExampleContext) in
            it("should enable the save button") {
                expect(subject.navigationItem.rightBarButtonItem?.enabled).to(beTruthy())
            }

            describe("tapping the save button") {
                var rootViewController: UIViewController! = nil
                var window: UIWindow? = nil
                beforeEach {
                    window = UIWindow()
                    window?.makeKeyAndVisible()
                    rootViewController = UIViewController()
                    window?.rootViewController = rootViewController
                    rootViewController.presentViewController(navigationController, animated: false, completion: nil)
                    expect(rootViewController.presentedViewController).toNot(beNil())

                    subject.navigationItem.leftBarButtonItem?.tap()
                    NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 2))
                }

                afterEach {
                    window?.hidden = true
                    window?.rootViewController = nil
                    window = nil
                }

                it("dismisses itself") {
                    expect(rootViewController.presentedViewController).toEventually(beNil())
                }

                it("saves the change to the userDefaults") {
                    let op = sharedContext()["saveToUserDefaults"] as? NSOperation
                    op?.main()
                }
            }
        }
    }
}

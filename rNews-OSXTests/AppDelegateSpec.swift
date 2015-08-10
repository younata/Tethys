import Quick
import Nimble
import Cocoa
import rNews
import Ra
import rNewsKit

class AppDelegateSpec: QuickSpec {
    override func spec() {
        var subject: AppDelegate! = nil
        var mainController: MainController! = nil

        beforeEach {
            subject = AppDelegate()

            mainController = MainController()
            subject.mainController = mainController
        }

        describe("applicationDidFinishLaunching:") {
            beforeEach {
                let note = NSNotification(name: "", object: nil)
                subject.applicationDidFinishLaunching(note)
            }

            it("should set the mainController's injector") {
                expect(mainController.raInjector).toNot(beNil())

                if let injector = mainController.raInjector {
                    expect(injector.create(DataWriter.self) as? DataWriter).toNot(beNil())
                    expect(injector.create(kMainMenu) as? NSMenu).toNot(beNil())
                }
            }
        }
    }
}

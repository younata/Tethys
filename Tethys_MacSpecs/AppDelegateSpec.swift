import Quick
import Nimble
import Cocoa
import Tethys
import TethysKit

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
                let note = Notification(name: Notification.Name(rawValue: ""), object: nil)
                subject.applicationDidFinishLaunching(note)
            }

            it("should set the mainController's injector") {
                expect(mainController.raInjector).toNot(beNil())

                if let injector = mainController.raInjector {
                    expect(injector.create(kind: DatabaseUseCase.self)).toNot(beNil())
                    expect(injector.create(string: kMainMenu) as? NSMenu).toNot(beNil())
                }
            }
        }
    }
}

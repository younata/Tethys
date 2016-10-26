import Quick
import Nimble
import Ra
import rNews

class AppModuleSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil
        var subject: AppModule! = nil

        beforeEach {
            injector = Injector()

            subject = AppModule()

            subject.configureInjector(injector: injector)
        }

        it("should configure the mainMenu correctly") {
            expect(injector.create(string: kMainMenu) as? NSMenu).to(beIdenticalTo(NSApp.mainMenu))
        }
    }
}

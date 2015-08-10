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

            subject.configureInjector(injector)
        }

        it("should configure the mainMenu correctly") {
            expect(injector.create(kMainMenu) as? NSMenu).to(beIdenticalTo(NSApp.mainMenu))
        }
    }
}

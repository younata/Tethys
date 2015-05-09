import Quick
import Nimble
import Ra
import Muon

class LocalImportViewControllerSpec: QuickSpec {
    override func spec() {
        var subject: LocalImportViewController! = nil
        var injector: Ra.Injector! = nil

        beforeEach {
            injector = Ra.Injector()
            subject = injector.create(LocalImportViewController.self) as! LocalImportViewController
            expect(subject.view).toNot(beNil())
        }

        afterEach {

        }

        describe("reloading objects") {
            beforeEach {

            }
        }
    }
}

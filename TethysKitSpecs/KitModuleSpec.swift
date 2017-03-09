import Quick
import Nimble
import Ra
#if os(iOS)
    import CoreSpotlight
#endif
@testable import TethysKit

class KitModuleSpec: QuickSpec {
    override func spec() {
        var injector: Injector! = nil

        beforeEach {
            injector = Injector(module: KitModule())
        }

        it("binds the main operation queue to kMainQueue") {
            expect(injector.create(kMainQueue) as? OperationQueue).to(beIdenticalTo(OperationQueue.main))
        }

        it("binds a single background queue") {
            expect(injector.create(kBackgroundQueue) as? NSObject).to(beIdenticalTo(injector.create(kBackgroundQueue) as? NSObject))
        }

        #if os(iOS)
            it("binds a searchIndex") {
                expect(injector.create(SearchIndex.self)! === CSSearchableIndex.default()) == true
            }
        #endif

        it("binds a URLSession to the shared session") {
            let urlSession = injector.create(URLSession.self)
            expect(urlSession).toNot(beNil())

            expect(urlSession) === URLSession.shared
        }

        it("binds a DatabaseUseCase") {
            expect(injector.create(DatabaseUseCase.self) is DefaultDatabaseUseCase) == true
        }

        it("binds an opml manager with a singleton scope") {
            expect(injector.create(OPMLService.self)).to(beIdenticalTo(injector.create(OPMLService.self)))
        }
    }
}
